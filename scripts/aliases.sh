#!/bin/bash
# Handy aliases

# Exit if there is any issue, do not continue execution

set -e

alias dxupdatecli='npm install --global sfdx-cli'
# Update installed programs in vs code using 'npm update -g'.
alias dxlist='sfdx force:org:list'
# Jump into the connected org
alias dxopen='sfdx force:org:open'
alias dxcreate='sfdx force:org:create --setdefaultusername --setalias ffdb --definitionfile config/project-scratch-def.json --targetdevhubusername=rtrigg1@globalfundforwomen.org'
alias dxpush='sfdx force:source:push &> push.log'
alias dxpull='sfdx force:source:pull &> pull.log'
# Before push or pull, compare project with scratch org.
alias dxstatus='sfdx force:source:status'

alias dxlistlogs='sfdx force:apex:log:list'
# To view log, grab log id from above command, and insert into following:
# sfdx force:apex:log:get --logid <log id>

# Delete all log files from connected org
# sfdx force:data:soql:query -q "SELECT Id FROM ApexLog" -r "csv" > out.csv
# sfdx force:data:bulk:delete -s ApexLog -f out.csv

# Retrieve metadata using manifest
# sfdx force:source:retrieve -x manifest/package.xml &> retrieve.log

# Run all tests for the org (except those from managed packages):
alias dxruntests='sfdx force:apex:test:run -c -r human -l RunLocalTests -d testruns &> testcoverage.log'

# Sample test run with code coverage results.
# sfdx force:apex:test:run -c -r human -n EndRequestControllerTest &> coverage.log

# Run all local apex tests.
# sfdx force:apex:test:run -c -r human -w 10 -l RunLocalTests &> coverage.log

# Deploy from manifest and run local tests
# sfdx force:source:deploy -x manifest/AQUpgrade/package.xml -l RunLocalTests &> coverage.log

# If apex test jobs are stuck in the queue, do this:
# sfdx force:apex:execute -f anonBlocks/AbortCompletedApexTestQueueItems.apex &> deploy.log

# Deploy from manifest and run local tests. Example for AQUpgrade project:
# sfdx force:source:deploy -x manifest/AQUpgrade/package.xml -l RunLocalTests &> coverage.log

# To delete apex code from sandbox or scratch org
# sfdx force:source:delete -m ApexClass:InviteGoToNewProposalController,ApexClass:InviteGoToNewProposalControllerTest

# To delete components from production, first modify this file: deployment/destructivePackage/destructiveChanges.xml
# In the style of the manifest's package.xml, it should specify the type name of component (e.g. ApexClass),
# and in 'members' tags, the names of the components to delete (e.g. a class name).
# This can also be used to efficiently delete old versions of processes and flows, where type is 'Flow' and members is say, 'Form_data_updated-11'.
# NOTE: the deployment/destructivePackage folder should also contain an "empty" package.xml file, specifying only the api version.
# Once the destructiveChanges.xml file is good to go, run this command (it takes a while): 
# sfdx force:mdapi:deploy -d deployment/destructivePackage -u devhub -l RunSpecifiedTests -r GenericUpdateRecordsBatchTest -w -1 &> deploy.log

# Sample deploy specifying metadata to deploy and test apex classes
# sfdx force:source:deploy -m ApexClass:AssessmentController,ApexClass:AssessmentControllerTest,CustomField:Assessment__c.Status_numeric__c -l RunSpecifiedTests -r AssessmentControllerTest
# sfdx force:source:deploy -m ApexClass:ProfileClassificationsInvocable,ApexClass:ProfileClassificationsInvocableTest -l RunSpecifiedTests -r ProfileClassificationsInvocableTest
# sfdx force:source:deploy -m ApexClass:OFACLookup,ApexClass:OFACLookupTest -l RunSpecifiedTests -r OFACLookupTest &> deploy.log
# sfdx force:source:deploy -m ApexClass:ProposalControllerClassifications,ApexClass:ProposalControllerClassificationsTest -l RunSpecifiedTests -r ProposalControllerClassificationsTest
# sfdx force:source:deploy -m ApexClass:ProjectionController,ApexClass:ProjectionControllerTest -l RunSpecifiedTests -r ProjectionControllerTest &> deploy.log
# sfdx force:source:deploy -m ApexClass:LetterController,ApexClass:LetterControllerTest -l RunSpecifiedTests -r LetterControllerTest &> deploy.log
# sfdx force:source:deploy -m AuraDefinitionBundle:AdvisorNew,ApexClass:AdvisorController,ApexClass:AdvisorControllerTest -l RunSpecifiedTests -r AdvisorControllerTest
# sfdx force:source:deploy -m LightningComponentBundle:advisorNewFromAccount,LightningComponentBundle:ldsUtils,AuraDefinitionBundle:AdvisorNewFromAccountWrapper,ApexClass:AdvisorController,ApexClass:AdvisorControllerTest -l RunSpecifiedTests -r AdvisorControllerTest
# sfdx force:source:deploy -m ApexClass:EndRequestController,ApexClass:EndRequestControllerTest -l RunSpecifiedTests -r EndRequestControllerTest
# sfdx force:source:deploy -m ApexClass:FormInstanceController,ApexClass:FormInstanceControllerTest -l RunSpecifiedTests -r FormInstanceControllerTest &> deploy.log
# sfdx force:source:deploy -m LightningComponentBundle:opportunityNewFromOpportunity,AuraDefinitionBundle:OpportunityNewFromOpportunityWrapper,ApexClass:OpportunityControllerTest -l RunSpecifiedTests -r OpportunityControllerTest &> deploy.log
# sfdx force:source:deploy -m ApexClass:OpportunityController,ApexClass:OpportunityControllerTest,ApexClass:OpportunityUpdateTotalsInvocable -l RunSpecifiedTests -r OpportunityControllerTest &> deploy.log
# sfdx force:source:deploy -m ApexClass:Utilities,ApexClass:UtilitiesTest -l RunSpecifiedTests -r UtilitiesTest &> deploy.log
# sfdx force:source:deploy -m AuraDefinitionBundle:GMDataEditSuper,AuraDefinitionBundle:IndicatorGroup,AuraDefinitionBundle:InputIndicator,ApexClass:GMDataController,ApexClass:GMDataControllerTest -l RunSpecifiedTests -r GMDataControllerTest

# Use this function of one arg to deploy a single class whose test class has same name with suffix "Test".
deployClassAndTest () {
    sfdx force:source:deploy -m ApexClass:$1,ApexClass:$1Test -l RunSpecifiedTests -r $1Test &> deploy.log
}

# Use this function of one arg to execute an apex file (with a .apex suffix) that lives in the scripts/apex folder.
executeApex () {
    sfdx force:apex:execute -f scripts/apex/$1 &> execute.log
}

# Run apex scripts like so:
# sfdx force:apex:execute -f scripts/apex/newAdvisorsFromJSON.apex &> execute.log

# To run a soql with the tooling api, add --usetoolingapi parameter, like so:
# sfdx force:data:soql:query -q "SELECT DeveloperName FROM GlobalValueSet" --usetoolingapi

###################
# SANDBOX: INSTALL DATA
###################
# Pull list of record type ids, then manually insert the ones in parentheses
#  into the Account (Organization_GM) and Contact (Contact_GM) data files.
alias dxrecordtypes='sfdx force:apex:execute -f scripts/apex/record-types.apex &> recordtypes.log'
# Install the rest of the data.
alias dxinstalldata='sfdx force:data:tree:import -p data/plan1.json --json &> installdata.log'
# If there are errors, it's best to delete all the data and start over from the first import step.
# To delete data:
# sfdx force:apex:execute -f scripts/apex/delete-data.apex --json &> installdata.log
# Importing specific data files doesn't correctly assign lookup fields, so in general, DON'T do this.
# sfdx force:data:tree:import -f data/Template__c.json -u ffdb --json &> installdata.log

###################
# GIT TIPS 
###################
# To push changes to git:
# git status (shows changed files)
# git add .
# git commit -m "DESCRIPTION OF CHANGES..."
# git push

# Get author, date, and message of last commit
# git log -1

# To connect a new vscode project to a new empty repo at github
# echo "# <name of project>" >> README.md
# git init
# git add README.md
# git commit -m "first commit"
# git branch -M main
# git remote add origin <URL of repo at github>
# git push -u origin main 

# To build a new vscode project on an existing non-empty git repo
# In vscode terminal (or windows command prompt), navigate to the Documents/Projects folder. 
# git clone <repo URL from github> <new project name>
# Open a new vscode window.
# File menu: Open folder (browse to the new project folder)
# git status # Should say "On Main" or some such
# Get on the correct branch if not main (and build local branch)
# git checkout --track origin/<branch name>

# Use 'git diff --cached' to see the changes made in the project as compared with latest commit at git branch.
# Show all local branches: 'git branch'

# Create a new branch:
# git checkout -b <branch name>
# Then push branch to github:
# git push -u origin <branch name> 
#
# After merge to main at github, bring local branch up to date:
# git checkout main // switch to main branch
# git remote update // pull down "knowledge" of changes at remote branch
# git status
# git pull origin main // pull down and incorporate changes locally on main branch

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

# AFFINAQUEST UPGRADE
# Deploy AccountController/Test classes first.
# Next, deploy all apex classes from manifest.
# Then deploy the AQUpgrade manifest. 
# NOTE: we're not deploying the summary fields in Contact (stashed in package1.xml). 
#   If necessary, "touch" (edit/save) those fields in Contact before deploying dependent metadata.