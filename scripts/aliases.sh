#!/bin/bash
# Handy aliases
# Exit if there is any issue, do not continue execution
set -e

# Run this script file (that is, instantiate the aliases defined here):
# source scripts/aliases.sh

alias dxupdatecli='npm install --global sfdx-cli'

alias dxlist='sfdx force:org:list'

# Retrieve metadata using manifest
# sfdx force:source:retrieve -x manifest/package.xml &> retrieve.log

###################
# SCRATCH ORG: CREATE, PUSH CODE, ASSIGN PERM SET
###################
alias dxcreate='sfdx force:org:create --durationdays 30 --setdefaultusername --setalias ffdb --definitionfile config/project-scratch-def.json --targetdevhubusername=rtrigg1@globalfundforwomen.org'
alias dxpassword='sfdx force:user:password:generate'
alias dxpush='sfdx force:source:push -f --json &>  push-results.log' 
# Install the data loader package from powerloader (using hard-wired package version id). 
alias dxinstalldataloader='sfdx force:package:install -p 04t440000009HJyAAM &> deploy-results.log'
# To get package version ids of other appexchange packages, use this command to list installed packages at devhub.
# sfdx force:package:installed:list -u devhub
# Create a new user - do we really need a second user?
# sfdx force:user:create --setalias qa-user --definitionfile config/user-def.json
alias dxpermsetassign='sfdx force:user:permset:assign -n FFDB_System_admin &> deploy.log'
alias dxdisplayuser='sfdx force:user:display --targetdevhubusername=rtrigg1@globalfundforwomen.org'

###################
# SCRATCH ORG: SET UP AND APEX TESTS
###################
# Jump into the connected scratch org (or sandbox)
alias dxopen='sfdx force:org:open'
# Turn on logging for User User
# Run all tests for the org (except those from managed packages):
alias dxruntests='sfdx force:apex:test:run -c -r human -l RunLocalTests -d testruns &> testcoverage.log'
# Jump into scratch org for these changes (can do this while tests are running):
#  - Edit Page on home page: Remove "Quarterly Performance" component
#  - App Manager: Assign Grantmaking/GM-admin/Fundraising apps to profiles: Read Only, Standard User, System Administrator
#  - App Menu: Make Grantmaking/GM-admin/Fundraising the topmost apps
#  - Object Manager: Set page layout assignments: Account, Contact, Fund
#  - ??? Company Info: Set default language to English to avoid the "startsWith" errors (Spanish doesn't care whether obj name starts with a vowel)

###################
# SCRATCH ORG: INSTALL DATA
###################
# Pull list of record type ids, then manually insert the ones in parentheses
#  into the Account (Organization_GM), Contact (Contact_GM), and Fund (Standard) data files.
alias dxrecordtypes='sfdx force:apex:execute -f scripts/apex/record-types.apex &> recordtypes.log'
# Use dataloader to insert the test records stored in "data (csv)" folder.
#...
# Install the rest of the data.
alias dxinstalldata='sfdx force:data:tree:import -p data/plan1.json --json &> installdata.log'
# If there are errors, it's best to delete all the data and start over from the first import step.
# To delete data:
# sfdx force:apex:execute -f scripts/apex/delete-data.apex --json
# Importing specific data files doesn't correctly assign lookup fields, so in general, DON'T do this.
# sfdx force:data:tree:import -f data/Template__c.json -u ffdb --json &> installdata.log
#
# After successful install of data, build a new letter for two of the proposals in the test data with these templates: 
#   Grant award notification message, and Decline letter.

###################
# SANDBOX
###################
# Connect to appropriate sandbox (e.g. ffdb-semillas), then do:
# dxpush
# dxopen
# In sandbox, set deliverability to all email
# dxruntests
# In sandbox setup:
#  - App Manager: Assign Grantmaking/GM-admin/Fundraising apps to profiles: Read Only, Standard User, System Administrator
#  - App Menu: Make Grantmaking/GM-admin/Fundraising the topmost apps
#  - Object Manager: Set page layout assignments: Account, Contact, Fund
#  - If WF is using Pending record type for Fund: Activate that record type, grant access to Standard and Pending in all profiles, and set Standard as default.
#       Also add Distributions (target) related list to Standard fund layout.
#  - If WF is doing fiscal sponsor, activate Org GM FS account record type, grant access in profiles.
#  - If WF is doing multi-currency (e.g. UWF), enable multi-currency, pick "company" currency, select other supported currencies, provide starting exchange rates.
#       Position the Currency fields in detail layouts for Payment, Proposal, Charge, Fund, Projection.
#       Either deploy currency-modified (UWF) Projection layout (metadataVariants/UWF/layouts), or make changes manually:
#         - Build new section "Currency conversion (for linked fund)" under "Totals (auto-maintained)"
#         - Add fields to the new section: Target_currency__c, Exchange_rate_to_target_currency__c, Total_grantmaking_converted__c
#         - Remove fields from right column of "Totals (auto-maintained)": Total_funds__c, Total_funds_for_GM__c, Total_charged__c, Remaining_to_charge__c
#       Deploy validation rules from metadataVariants/UWF/validationRules. 
#         EXCEPT deactivate the CurrencyClash validation rule on Payment!!
#  - If WF makes grants to multiple countries, then turn on the schedule class for computing the country-based statistics.
#  - Duplicate rules: Among the active account and contact rules, add a condition that account/contact record type does not contain GM. 
#  - Company Info: Set default language to English to avoid the "startsWith" errors (Spanish doesn't care whether obj name starts with a vowel)
# Update record types and then install test data:
# dxrecordtypes
# Import data

###################
# TRANSLATION 
###################
# Push latest changes to the scratch org.
# Setup - Translation workbench - Export
# To translate all metadata, choose Source and export as stf.  
# When the email arrives, follow link to the doc inside salesforce. 
# Follow link in Recent Documents to pull up document record.
# Click "View file" to download file.
# Open file from excel, choose Delimited, with tab as delimiter.
# Follow instructions at top of file.  Basically, change the #Language row to have desired language, 
# and replace the LABEL column with translations in that language. 

###################
# MISCELLANEOUS
###################
# alias dxscratchorgstartup='dxcreate;dxpush;dxcreateuser;dxpermsetassign;dxopen'

# In case the Grantmaking custom application isn't "pushed", then try this:
# sfdx force:source:deploy -m CustomApplication:Grantmaking --json &> deploy-results.log

# Be sure to turn on logging (for tester11 and User User) in the scratch org before running tests. 
# Can run apex tests on specific (comma-separated) test classes like so:
# sfdx force:apex:test:run -w 20 -c -r human -t EndRequestControllerTest &> testcoverage.log
# I'm not seeing code coverage percentages for each class from the above call. 
# However, once you have the report id, this works (drop the -c to get a simple pass/fail as opposed to percentage coverage):
# sfdx force:apex:test:report -c -i 707xxxxxxxxxxx
alias dxlistlogs='sfdx force:apex:log:list'
# To view log, grab log id from above command, and insert into following:
# sfdx force:apex:log:get --logid <log id>

# If apex test jobs are stuck in the queue, do this:
# sfdx force:apex:execute -f anonBlocks/AbortCompletedApexTestQueueItems.apex &> deploy.log

# Delete all log files from connected org
# sfdx force:data:soql:query -q "SELECT Id FROM ApexLog" -r "csv" > out.csv
# sfdx force:data:bulk:delete -s ApexLog -f out.csv

# Before push or pull, compare project with scratch org.
alias dxstatus='sfdx force:source:status &> status.log'
alias dxpull='sfdx force:source:pull -f &> pull-results.log'
# To recover some bit of (say, accidentally deleted) metadata from devhub
# sfdx force:source:retrieve --targetusername=rtrigg1@globalfundforwomen.org -m CustomField:Proposal__c.Date_declined__c
# To retrieve report structure from a sandbox or production. Get developer name of report using Properties option under "Save" menu in report editor.
# Note that it consistently outputs a "No results found" message even when the report is successfully retrieved/updated.
# sfdx force:source:retrieve -m "Report:<folder name>/<developer name of report>,..."
# for example:
# sfdx force:source:retrieve -m "Report:FFDB/* TEMPLATE REPORTS/Projections_TEMPLATE_Mq4"

# To delete metadata from scratch org (sometimes necessary when push is stuck)
# sfdx force:source:delete -m ApexClass:InviteGoToNewProposalController,ApexClass:InviteGoToNewProposalControllerTest

# If push to scratch org breaks with connection error, then deploy to the scratch org instead with something like this:
# sfdx force:source:deploy -m CustomObject,ApexClass,FlexiPage --json &> deploy-results.log


# Use following or dxdisplayuser alias to find the "instance url" to connect to scratch org as that user.
# sfdx force:user:display --targetdevhubusername=rtrigg1@globalfundforwomen.org -u ffdb

# WF sandboxes: authorize and deploy, for example for ffdb-rwf:
# sfdx force:auth:web:login -r https://test.salesforce.com -a ffdb-rwf
# sfdx force:source:deploy -x manifest/package.xml -u ffdb-rwf &> deploy-results.log
# sfdx force:org:open -u ffdb-rwf
# From inside sandbox post-deployment: 
#  - Add folks (including me) to ffdb permission set (Permission Set manage assignments)
#  - Set email access level to All email (setup -> deliverability )
#  - If necessary, build SFDC_DevConsole debug level (Debug Logs)
#  - Turn on logging
# Run apex tests
# sfdx force:apex:test:run -c -r human -l RunLocalTests -d testruns > testcoverage.log
# Jump back into sandbox for these changes:
#  - Assign Grantmaking app to all profiles (App Manager)
#  - Make Grantmaking the topmost app (App Menu)
#  - Set page layout assignments: Account, Contact, Fund
#  - Remove "Quarterly Performance" component from home page (Edit Page)
# Fix record types
# sfdx force:apex:execute -f anonBlocks/record-types.apex -u ffdb-rwf &> recordtypes.log
# Install template records to prevent ProposalUpdate from breaking when props are imported.
# sfdx force:data:tree:import -p data/plan_ProposalStatusTemplate.json -u ffdb-rwf --json &> installdata.log
# Use dataloader to import the "Proposal status" template macros
# ...
# Now import rest of the data
# sfdx force:data:tree:import -p data/plan1.json -u ffdb-rwf --json &> installdata.log
# To push data for specific object(s) (e.g. just portfolios and assigns) as opposed to entire "plan"
# sfdx force:data:tree:import -f data/Portfolio__c.json,data/Portfolio_Account_Assign__c.json -u ffdb-rwf --json
# To delete data
# sfdx force:apex:execute -f anonBlocks/delete-data.apex -u ffdb-rwf --json
alias dxsetwfaliases="sfdx force:alias:set ffdb-rwf=rtriggrwf@globalfundforwomen.org ffdb-semillas=rtriggsemillas@globalfundforwomen.org ffdb-uwf=rtrigguwf@globalfundforwomen.org"

###################
# TIPS 
###################
# Fix as many of the push errors as possible.  If the errors are inscrutable, try creating a new scratch org and push there.

# Push after every change if possible!!  (Otherwise, changes bank up and push takes forever.)

# Think carefully about whether to make changes to source in the sfdx project and push, versus in the scratch org and pull.
# For example, it's easy to change values on a global value set in source,
# however, then you have to modify every record type that references the picklist.
# Making the change at the scratch org should auto-adjust the record types, and you can update source with a single pull.

# To delete a field/object or change its name, first, check that the component doesn't appear in apex code. 
# If it does, comment it out (or remove) in source and push to scratch org.  
# Then do the actual delete/change in the scratch org and pull.
# Don't forget to change ALL occurrences of the object/field name 
# including in related lists, tabs, layouts, etc. Also the relevant file names. Then fix the class names and method names.
# Keep an eye out for variable names that need renaming to align with the new obj/fld name.

# If push or apex tests results in Error: getaddrinfo ENOTFOUND, jump into the org and look at deployment status to see errors.

# When push isn't usable, use this function of one arg to deploy a single class whose test class has same name with suffix "Test".
deployClassAndTest () {
    sfdx force:source:deploy -m ApexClass:$1,ApexClass:$1Test -l RunSpecifiedTests -r $1Test &> testcoverage.log
}

# Use this function of one arg to execute an apex file (with a .apex suffix) that lives in the scripts/apex folder.
executeApex () {
    sfdx force:apex:execute -f scripts/apex/$1 &> execute.log
}

# To run a soql with the tooling api, add --usetoolingapi parameter, like so:
# sfdx force:data:soql:query -q "SELECT DeveloperName FROM GlobalValueSet" --usetoolingapi

# After doing field/object deletes or renames, push to a new scratch org if possible to ensure that metadata files haven't been corrupted.
# If a custom object's metadata file has been trashed (e.g. missing label),
# then recover from github by finding the file in the browser and then clicking "History".

###################
# DESTRUCTIVE CHANGES 
###################
# For example, after upgrading ffdb in an org, metadata that is deleted in ffdb is marked as deprecated in the org. 
# Use destructive changes to delete such deprecated data from the org.
#   Create a top-level directory in the project called, say, destructive
#   Include an empty package.xml (the shell)
#   Include a manifest of the metadata to deploy called destructiveChanges.xml
#   Do the deletes in the target org:
#   sfdx force:mdapi:deploy -d destructive -u [TARGETORG] -w -1 &> deploy.log
#   NOTE: the deletes are not purged, so have to go into the delete and "erase" to completely remove. Ugh.
#   NOTE: Fails if manifest includes metadata that has already been deleted. Have to create a new manifest (and folder) containing only the yet-to-delete metadata.  

###################
# GIT TIPS 
###################
# To push changes to git:
# git status (shows changed files)
# git add .
# git commit -m "DESCRIPTION OF CHANGES..."
# git push

# To start fresh
# git clone <repo URL from github> <new project name>
# Get on the correct branch if not master
# git checkout <branch name>

# Use 'git diff --cached' to see the changes made in the project as compared with latest commit at git branch.
# Show all local branches: 'git branch'
# Create a new branch:
# git checkout -b test-deploy-rt
# Then push branch to github:
# git push -u origin test-deploy-rt 
#
# After merge to master at github, bring local branch up to date:
# git checkout master
# git remote update
# git status
# git pull origin master
# git checkout test-deploy-rt

# git branch -u origin/[branchname]

# this command creates a new branch locally and connects to remote branch in one step
# git checkout -b <nameofbranchforlocal> origin/<nameofbranch>

# Get state of remote branches 
# git remote update 

# Delete local branch
# git branch -d <local-branch>

# Merge one branch into the branch that is checked out
# git merge <name of branch to merge>

# To merge into a new remote branch
# git remote update
# git branch 
# git checkout <name of new branch>
# git pull
# git checkout <name of original branch>
# git merge <name of new branch to merge> 

# Create a new branch:
# git checkout -b <branch name>
# Then push branch to github:
# git push -u origin <branch name> 

# After merge to main at github, bring local branch up to date:
# git checkout main // switch to main branch
# git remote update // pull down "knowledge" of changes at remote branch
# git status
# git pull origin main // pull down and incorporate changes locally on main branch

###################
# PACKAGE TIPS 
###################

# To initially create a package and initial version
# sfdx force:package:create --name ffdbpkg_test --description "Test Packaging of FFDB" --packagetype Unlocked --path force-app --nonamespace --targetdevhubusername devhub 

# To create a new package version.  Set (increment) the version number in sfdx-project.json.  -k gives the password.  
# Wait time is in minutes.  Can try longer wait time (e.g. 60), but may have to cut back to 5 with polling to avoid EAI_AGAIN errors.
# Note that --codecoverage forces test code to run to check 75% coverage.
# sfdx force:package:version:create -p ffdbpkg -d force-app -k ffdb --wait 5 -v devhub --codecoverage -f config/project-scratch-def.json &> package.log
# After completion, build a new packageAliases entry in sfdx-project.json with the new subscriber package version id (04t...). 

# Use this to ping for how it's doing, and errors when it's done. Above command provides create version request id when it times out.
# sfdx force:package:version:create:report -i [Request Id 08c...]

# If version creation completes on its own, it will create new line in sfdx-project.
# Otherwise, when version creation completes, grab Subscriber Package Version Id and insert new line in sfdx-project.json with version # and id.

# Get info on all versions of the package
# sfdx force:package:version:create:list

# Get install links for all versions 
# sfdx force:package:version:list --verbose

# To set and change installation key (aka password): https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_dev2gp_config_installkey.htm

# Package must be "released" before installing in production (the Released column in sfdx force:package:version:list should be "true").
# Promote package to "released" - grab full package alias with version num from sfdx-project.json.
# sfdx force:package:version:promote -n --package "[VERSION ALIAS]"

# Update name of package, for example:
# sfdx force:package:update -p ffdbpkg_test -n ffdbpkg
# Update description of package, for example (-p can be package name or 0Ho... id):
# sfdx force:package:update -p ffdbpkg -d "Feminist Fund Database package"

# Before installing package at a WF, be sure that:
#   History tracking is enabled for Account, Contact, and Opportunity
# To install package version in the currently connected sandbox or production org
# sfdx force:package:install -t Mixed --wait 10 --package <package version name with version number> -k ffdb --noprompt -s AllUsers

# After install:
#  Add CRUD access to the NPSP opp payment object to ffdb permission sets.
#  Assign permission set to users. Delete old permission set if necessary after reassigning users.
#  OPTIONAL: Install dataloader.io from appexchange: https://appexchange.salesforce.com/appxListingDetail?listingId=a0N30000009wRkqEAE (first login with a production login, then choose to install in Sandbox)
# In a sandbox, dataloader may not work.  If so, uncheck the two VF-related "Enable clickjack protection..." checkboxes in Setup -> Session Settings.
#  Use App Menu to position our three apps at or near the top (below NPSP and Volunteers?).
#  In Object Manager, set page layout assignments for Account, Contact, Fund. Also Proposal if in Semillas.
#  In Opportunity page layout, add Payments and Projections as top related lists.
#  In Allocation and Invite objects, remove New button from the Search Layouts for Salesforce Classic.
#  Install test data if desired:
#   - Using dxrecordtypes, assign record types for Account, Contact, Fund.  
#   - do initial imports, using built-in data import wizard if Configero data loader doesn't work.
#   - dxinstalldata
#   - build letters for two of the proposals (decline and grant award notification) 
#   - For Account and Contact, activate the FFDB lightning record pages appropriately for three apps: Grantmaking, GM_Admin, and Fundraising. 
#   - If non-English, then adjust Letter__c.Language__c formula field to default to the appropriate language, 
#   - likewise the default value for the Template_Piece__c.Language__c picklist.
#  Deploy global value set metadata for the particular WF

# After upgrading package
#  In addition to above tasks where necessary...
#  Delete deprecated fields (unless they contain data), and erase any deleted fields not yet purged.  
#  For example, if Proposal__c.GM_Data_prop__c still exists, ensure that GM_Data__c is populated for existing props, and then delete GM_Data_prop__c.
#  Check that replacements for deleted fields (say, field name/type changes) still appear in layouts. 
#  If not, try removing then adding to the layout. Or undo and then redo the page layout assignment for that record type. 
#  Check permission set assignments.
#  If reports weren't updated, try deploying one from sfdx to see the problem. If a report type complains, delete it at org, then redeploy. Then re-deploy reports.

# Importing data at UWF using Data Import Wizard (Ukrainian text requires true UTF-8, which configero dataloader doesn't handle)
# Use Libre Office to avoid the problem of excel losing UTF-8 when saving as csv.
#  Accounts: Include a blank Last Name column and map it to Contact Last Name - that prevents contact records from being created.
#   Note that we're only allowed to insert accounts with a single record type. So do separate inserts for GM and FR.
#  Contacts: Can't seem to get external id field to work to link contact to account.  Work-around: import contacts with configero, letting 
#   first/last name fields be garbaged. Export a report that includes the account external id and the contact id.  In libre office, use vlookup
#   to find matching rows in contact data, and pull the Ukrainian name columns. (Watch out for accs w/ multiple contacts.)
#   Then use data import wizard to update the contacts matching on Salesforce.com Id field. 
#   The good news is that the record type column can be mapped, so one insert can bring in contacts of different record types.
#  Custom objects: Should be able to insert new records using external id fields to link (e.g. to Proposal records).
#  There's no way to specify batch size. So it's best to deactivate any relevant processes and flows. That may require post-processing,
#    for example, to ensure that proposals get their status (re)set.
#  DATES: In Libre office, be sure that date columns are formatted as dates not text (right-justified), and that they are formatted as
#    as English UK to get DD/MM/YYYY. Can convert column from text to date using this trick: 
#    https://ask.libreoffice.org/en/question/6466/trouble-formatting-date-cells-in-calc/
#    If importing with configero data loader, format dates as 2020-03-31.
