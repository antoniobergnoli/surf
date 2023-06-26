## How to sync with upstream

```
# Add a new remote upstream repository
git remote add upstream https://github.com/slaclab/surf.git

# Sync your fork
git fetch upstream
git checkout master
git merge upstream/master
```

# SURF

SLAC Ultimate RTL Framework

<!--- ########################################################################################### -->

# Before you clone the GIT repository

Setup for large filesystems on github.  `git-lfs` used for all binary files (example: .dcp)

```sh
$ git lfs install
```

<!--- ########################################################################################### -->

# Documentation

[An Introduction to SURF Presentation](https://docs.google.com/presentation/d/1kvzXiByE8WISo40Xd573DdR7dQU4BpDQGwEgNyeJjTI/edit?usp=sharing)

[Doxygen Homepage](https://slaclab.github.io/surf/index.html)

[Support Homepage](https://confluence.slac.stanford.edu/display/ppareg/Build+System%3A+Vivado+Support)

[Bug Tracking](https://jira.slac.stanford.edu/projects/ESSURF)

<!--- ########################################################################################### -->
