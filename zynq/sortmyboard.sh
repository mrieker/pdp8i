#!/bin/bash
set -e

rm -f x.x
sed 's;Path=".*/pdp8i.xpr";Path="pdp8i.xpr";g' pdp8i.xpr > x.x
if diff -q x.x pdp8i.xpr
then
    rm x.x
else
    mv -v x.x pdp8i.xpr
fi

if [ SortJSon.jar -ot SortJSon.java ]
then
    rm -f SortJSon*.class SortJSon.jar
    javac SortJSon.java
    jar cf SortJSon.jar SortJSon*.class
    rm -f SortJSon*.class
fi

rm -f x.x
CLASSPATH=SortJSon.jar java SortJSon < myboard/myboard.bd > x.x
if diff -q x.x myboard/myboard.bd
then
    rm x.x
else
    mv -v x.x myboard/myboard.bd
fi

if [ SortWrapper.class -ot SortWrapper.java ]
then
    rm -f SortWrapper.class
    javac SortWrapper.java
fi

rm -f x.y
CLASSPATH=. java SortWrapper < myboard/hdl/myboard_wrapper.vhd | grep -v '^--Date' > x.y
if diff -q x.y myboard/hdl/myboard_wrapper.vhd
then
    rm x.y
else
    mv -v x.y myboard/hdl/myboard_wrapper.vhd
fi
