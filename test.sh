#!/bin/sh
# Usage:
# sh test.sh -j8
# PROJECT=json-validator sh test.sh -j8
# HASH_ITERATIONS=10 sh test.sh -v t/plugin-yaml.t
# PERL_HASH_SEED=8 sh test.sh -v t/plugin-yaml.t

export PERL5LIB=$PWD/lib;
# export SWAGGER2_DEBUG=1;

t () {
  echo "\$ cd ../$PROJECT && prove -l $@";
  cd ../$PROJECT && prove -l $@ || exit $?;
}

if [ -n "$PERL_HASH_SEED" ]; then
  export PERL_PERTURB_KEYS=NO;
fi

HASH_ITERATIONS=${HASH_ITERATIONS:-0}
if [ $HASH_ITERATIONS -gt 0 ]; then
  for i in $(seq 1 $HASH_ITERATIONS); do
    export HASH_ITERATIONS=0;
    export PERL_HASH_SEED=$i;
    echo "\$ export PERL_HASH_SEED=$PERL_HASH_SEED";
    sh $0 $@ || break
  done
elif [ "x$PROJECT" != "x" ]; then
  t $@;
else
  PROJECT=json-validator t $@;
  PROJECT=mojolicious-plugin-openapi t $@;
fi

exit $?;
