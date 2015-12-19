# git-subcommands
Effective &amp; Convenience subcommands.

## Ahead

Show the information of 'Your branch is ahead of tracking branch by xxx commits.'

list : show hashes of such commits  
count : number of such commits  
first : the hash of first commit in such commits

## Branch Extra

Show the information of branches on local/remote

list : listing all brances on local and remote  
list-local : listing all branches on local  
list-remote : listing all branches on remote  
current : show the local branch which you are now on  
tracked : show the remote branch that the current branch is tracking
exists : check whether the specified branch exists or not  
mergable : check whether the specified branch can merge into the current branch

## Ignore

Manage .gitignore with using gitignore.io

create : create new .gitignore  
append : append ignore items to existed .gitignore  
add : add the specified pattern to .gitignore  
remove : remove the specified pattern from .gitignore  
has : check whether the specified pattern exists or not
list : show all ignored patterns.

## License

Fetch a license you specified via Github License api

