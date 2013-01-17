#!/bin/bash
# This is a bundle pre-install script for GPGPreferences.


# config #######################################################################
linkPath="${2%/*}"
sysdir="/Library/PreferencePanes"
homedir="$HOME/Library/PreferencePanes"
bundle="GPGPreferences.prefPane"
################################################################################

# determine where to install the bundle to #####################################
if [[ -e "$homedir/$bundle" ]]; then
    target="$homedir"
else
    target="$sysdir"
fi
################################################################################

# make a symlink to the install location  ######################################
rm -rf "$linkPath"
mkdir -p "${linkPath%/*}"
ln -s "$target" "$linkPath" || exit 1
################################################################################

exit 0