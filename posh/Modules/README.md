# POSH Modules
POSH modules are simply files namwed with `*.psm1` extension. For these files to function per user profile they must:
- Live in a folder named exactly as at least one of the scripts contained in the directory.
  - ex: if script is named `fleeting_fling.psm1`, then it will be visible to POSH if within directory named `fleeting_fling` (see next bullet point), and
- Folder in bullet point above in turn lives in directory called `Modules` as a child of the user POSH directory.

So, the file `fleeting_fling.psm1` should be copied to `C:\Users\{username}\Documents\WindowsPowerShell\Modules\fleeting_fling\` on your machine. 

Then, when you open a new POSH instance, you can verify this by `Get-Module -List` and look for your module file.

The last thing in order for this to work, you have to uncomment the import line in the main profile script:

`Import-Module fleeting_fling`

# fleeting_fling, what do you do for me?
fleeting_fling.psm1 has just a few helpers. Once installed, from POSH you can:
`fling`: cd to fling directory
`fling 1`: anything after fling so it is not null will cd you to fling dir and also run `start_fling`
`start_fling`: do the stuff needed to activate venv, compose docker stuff and so on to run fleeting_fling.
`psdir`: go the location of your POSH profile file(s)
`cu`: go to your `u` directory

#Other Stuff
Couple of other cmds that are useful:

`$profile`: shows path to your POSH profile script.
`refreshenv`: refreshes POSH environment variables
`$env:PSModulePath`: look at the two default module paths wired into POSH by default (one of them being your user path)