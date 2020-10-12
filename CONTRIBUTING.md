# HOW TO CONTRIBUTE

Thank you for considering contributing to this distribution. This file
contains instructions that will help you work with the source code.

## Getting dependencies

If you have App::cpanminus installed, you can use
[cpanm](https://metacpan.org/pod/cpanm) to satisfy dependencies like this:

    cpanm --installdeps --with-develop .

You can also run this command (or any other cpanm command) without installing
App::cpanminus first, using the fatpacked `cpanm` script via curl or wget:

    curl -L https://cpanmin.us | perl - --installdeps --with-develop .
    wget -qO - https://cpanmin.us | perl - --installdeps --with-develop .

Otherwise, look for either a `cpanfile` or `META.json` file for a list of
dependencies to satisfy.

There are also some optional modules which should be installe if you
are contributing a code change:

    cpanm boolean
    cpanm Sereal::Encoder 4.00
    cpanm Test::JSON::Schema::Acceptance 1.000
    cpanm YAML::XS 0.67
    cpanm Test::Pod
    cpanm Test::Pod::Coverage

## Running tests

You can run tests directly using the `prove` tool:

    prove -l
    prove -lv t/some_test_file.t

For most of my distributions, `prove` is entirely sufficient for you to test
any patches you have. I use `prove` for 99% of my testing during development.

## Reporting bugs

First of all, make sure you are using the latest version of JSON::Validator and
its dependencies, it is quite likely that your bug has already been fixed. If
that doesn't help, take a look at the list of currently open issues, perhaps it
has already been reported by someone else and you can just add a comment
confirming it.

If it hasn't been reported yet, try to prepare a test case demonstrating the
bug, you are not expected to fix it yourself, but you'll have to make sure the
developers can replicate your problem. Sending in your whole application
generally does more harm than good, the t directory of this distribution has
many good examples for how to do it right. Writing a test is usually the
hardest part of fixing a bug, so the better your test case the faster it can be
fixed.

And don't forget to add a descriptive title and text, when you create a new
issue. If your issue does not contain enough information or is unintelligible,
it might get closed pretty quickly. But don't be disheartened, if there's new
activity it will get reopened just as quickly.

## Code style

The code style is enforced with a `.perltidyrc` in the project root. Any pull
request or patch should be run through
[Perl::Tidy](https://metacpan.org/pod/distribution/Perl-Tidy/bin/perltidy)
before submitted. This can easily be enforced using a tool such as
[githook-perltidy](https://metacpan.org/pod/githook-perltidy).

## Changes file

Do not change the `Changes` file when working on a patch or "pull request".
This file will be updated appropriately when a new release is made.

# CREDITS

This file was adapted from an initial `CONTRIBUTING.md` file from
[Mojo::SQLite](https://github.com/Grinnz/Mojo-SQLite/blob/master/CONTRIBUTING.md),
and paragraphs as heavily influenced by https://docs.mojolicious.org/Mojolicious/Guides/Contributing.
