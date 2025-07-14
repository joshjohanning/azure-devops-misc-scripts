#!/bin/bash

echo -n "NuGet feed name?"
read nugetfeed

echo -n "NuGet feed source?"
read nugetsource

echo -n "Enter PAT"
read pat

# adding to ~/.config/NuGet/NuGet.config
nuget sources add -Name $nugetfeed -Source $nugetsource -username "az" -password $pat 

results=$(find . -name "*.nupkg")
resultsArray=($results)

#echo "${resultsArray[*]}"

for var in "${resultsArray[@]}"
do
    echo $var
    nuget push -Source $nugetfeed -ApiKey az $var
done
