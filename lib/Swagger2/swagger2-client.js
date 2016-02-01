(function() {
  /**
   * @file Generate object for communicating with a Swagger backend.
   * @version 0.70.0
   * @author Jan Henning Thorsen
   * @copyright Jan Henning Thorsen 2016
   * @license Artistic License version 2.0.
   */

  /**
   * Generates a new client from a Swagger specification.
   * Note that the specification specification cannot contain "$ref" and need
   * to be in JSON format.
   * @class
   * @param {(string|Object)} spec - Either an object representing a Swagger spec or the URL to the Swagger specification file.
   * @param {function} [cb] - Function to call when the spec URL is downloaded.
   * @example
   * var client = new swaggerClient(url, function(err) {
   *   if (err) throw err;
   *   this.listPets({limit: 10}, function(err, xhr) {
   *     console.log(xhr.code, xhr.body);
   *   });
   * });
   */
  function swaggerClient(spec, cb) {
    this._id = 1;
    this._xhr = {};
    if (typeof spec == 'object') return this._generate(spec);
    if (typeof spec == 'string') return this._load(spec, cb);
  };

  var proto = swaggerClient.prototype;
  var cache = {}, makeErr;

  /**
   * Get cached XMLHttpRequest object
   * @param {string} operationId - Name of operationId from Swagger specification
   * @return {Object} xhr - A XMLHttpRequest object
   * @example
   * xhr = client.cached("listPets");
   */
  proto.cached = function(operationId) { return cache[operationId]; };

  /**
   * Force getting fresh data from server
   * @return {Object} client - Self.
   * @example
   * client.fresh().listPets({}, function(err, xhr) {});
   */
  proto.fresh = function() { this._fresh = true; return this; };

  /**
   * Used to set a WebSocket object which can talk Swagger.
   * The WebSocket object must fire a "json" event.
   * @return {Object} client - Self.
   * @example
   * client.fresh().listPets({}, function(err, xhr) {});
   */
  proto.ws = function(ws) {
    var self = this;
    self._ws = ws;
    ws.on('json', function(res) {
      if (!res.id || !res.code) return;
      var xhr = self._xhr[res.id];
      if (!xhr) return;
      delete self._xhr[res.id];
      xhr.status = res.code;
      xhr.body = res.body;
      if (window.DEBUG) console.log('[Swagger] ' + xhr.op + ' ' + xhr.status + ' ' + JSON.stringify(xhr.body));
      xhr.call(self, makeErr(xhr), xhr);
    });
    return self;
  };

  // Generate methods from spec
  proto._generate = function(spec) {
    var self = this;
    this.baseUrl = (spec.basePath || '').replace(/\/$/, '');
    this._fresh = false;

    Object.keys(spec.paths).forEach(function(path) {
      if (path.indexOf('/') != 0) return;
      Object.keys(spec.paths[path]).forEach(function(httpMethod) {
        if (!httpMethod.match(/^\w+$/)) return;
        var opSpec = spec.paths[path][httpMethod];
        var pathList = path.split('/');
        httpMethod = httpMethod.toUpperCase();
        pathList.shift(); // first element is empty string

        if (window.DEBUG == 2) console.log('[Swagger] Add method ' + opSpec.operationId);
        self[opSpec.operationId] = function(input, cb) {
          var xhr = this._fresh ? false : this.cached(opSpec.operationId);

          if (xhr) {
            if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' is cached');
            setTimeout(function() { cb.call(this, null, xhr) }.bind(this), 0);
          }
          else if(this._ws && this._ws.readyState == WebSocket.OPEN) {
            this._ws.send({id: this._id, op: opSpec.operationId, params: input});
            this._xhr[this._id++] = cb;
            cb.op = opSpec.operationId;
          }
          else {
            xhr = this._xhrReq(httpMethod, pathList, input, opSpec.parameters || []);
            this._fresh = false; // reset on each request
            if (xhr.errors) {
              setTimeout(function() { cb.call(this, xhr.errors, xhr) }.bind(this), 0);
            }
            else {
              xhr.onreadystatechange = function() {
                if (xhr.readyState != 4) return;
                if (httpMethod == 'GET' && xhr.status == 200) cache[httpMethod + ':' + xhr.url] = xhr;
                if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' ' + xhr.status + ' ' + xhr.responseText);
                xhr.body = xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : xhr.responseText;
                cb.call(this, makeErr(xhr), xhr);
              }.bind(this);
              xhr.send(xhr.body);
              delete xhr.body;
            }
          }
        };
      });
    });

    return this;
  };

  // Load Swagger specification from URL
  proto._load = function(url, cb) {
    var xhr = new XMLHttpRequest();

    xhr.open('GET', url);
    xhr.onreadystatechange = function() {
      if (xhr.readyState != 4) return;
      if (xhr.status != 200) return cb.call(this, xhr.status);
      if (window.DEBUG == 1) console.log('[Swagger] Generate methods from ' + url);
      this._generate(xhr.responseText.match(/^[\{\[]/) ? JSON.parse(xhr.responseText) : {});
      cb.call(this, '');
    }.bind(this);
    xhr.send(null);

    return this;
  };

  // Create a request
  proto._xhrReq = function(httpMethod, pathList, input, parameters) {
    var xhr = new XMLHttpRequest();
    var form = [], headers = [], json = null, query = [], str;
    var url = [this.baseUrl];
    var errors = [];

    pathList.forEach(function(p) {
      url.push(p.replace(/\{(\w+)\}/, function(m, n) {
        if (typeof input[n] == 'undefined') errors.push({message: 'Missing input: ' + n, path: '/' + n});
        return input[n];
      }));
    });

    xhr.body = null;
    xhr.url = url.join('/');

    for (i = 0; i < parameters.length; i++) {
      var p = parameters[i];
      var name = p.name;
      var value = input[name];

      if (typeof value == 'undefined') {
        value = p['default'];
      }
      if (typeof value == 'undefined') {
        if (p.required) errors.push({message: 'Missing input: ' + name, path: '/' + name});
        continue;
      }

      switch (p['in']) {
        case 'body':     json = value;                break;
        case 'file':     xhr.body = value;            break;
        case 'formData': form.push([name, value]);    break;
        case 'header':   headers.push([name, value]); break;
        case 'query':    query.push([name, value]);   break;
      }
    }

    if (errors.length) {
      if (window.DEBUG) console.log('[Swagger] ' + xhr.url + ' = ' + JSON.stringify(errors));
      xhr.errors = errors;
      return xhr;
    }
    if (query.length) {
      str = [];
      query.forEach(function(i) { str.push(encodeURIComponent(i[0]) + '=' + encodeURIComponent(i[1])); });
      xhr.url += '?' + str.join('&');
    }

    if (json) {
      headers.unshift(['Content-Type', 'application/json']);
      xhr.body = JSON.stringify(json);
      if (window.DEBUG == 2) console.log('[Swagger] ' + xhr.url + ' <<< ' + xhr.body);
    }
    else if(form.length) {
      str = [];
      headers.unshift(['Content-Type', 'application/x-www-form-urlencoded']);
      form.forEach(function(i) { str.push(encodeURIComponent(i[0]) + '=' + encodeURIComponent(i[1])); });
      xhr.body = str.join('&');
      if (window.DEBUG == 2) console.log('[Swagger] ' + xhr.url + ' <<< ' + xhr.body);
    }

    xhr.open(httpMethod, xhr.url);
    headers.forEach(function(i) { xhr.setRequestHeader(i[0], i[1]); });

    return xhr;
  };

  var makeErr = function(xhr) {
    var errors = xhr.body.errors || [];
    if (xhr.status == 200) return null;
    if (errors.length) return errors;
    if (!xhr.status) xhr.status = 408;
    return [{message: "Something very bad happened! Try again later. (" + xhr.status + ")", path: xhr.url}];
  };
})();
