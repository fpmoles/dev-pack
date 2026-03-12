# Installation Script Plan

## Objective
Create an installation script that be run on a developer machine to make the scripts, skills, and agents available for use.

## Context
This set of tools is designed to be used on all of my development machines and keep things in sync.
The initial setup of a development machine is controlled by local-setup in ${CODE_HOME}/local-setup, which includes a setup.sh script that installs dependencies and configures the environment.

## Scope

### In Scope
* A repeatable installation script that can be run on a developer machine to make the scripts, skills, and agents available for use.
* Operation should be able to be repeated on each pull or push of the latest code to keep the local environment up to date.
* Symlinks are preferred rather than copying files to avoid duplication and ensure updates are reflected without needing to re-run the installation script.
* The ai agents and skills should be available to any coding agent, not just the current one, to allow for flexibility in how they are used.

### Out of Scope
* installation of coding agents themselves
* installation of dependencies, however warn me if things are missing that need to be added to the local-setup script

## Requirements
* The script should ensure that the environment variables used are on the PATH, if they are not it should alert the user to run the local-setup script to set them up.
    * The script should specifically look for ${DEV_HOME}, ${CODE_HOME}, ${SCRIPTS_HOME}, and ${TEMPLATES_HOME} and alert if they are not set or not on the PATH.
    * The script should then simply reference those locations for the rest of its operations without needing to modify them or set them itself.
* The script should clone the repo (https://github.com/fpmoles/dev-pack) to ${CODE_HOME} if it is not already present, but should not delete or modify any existing files in that directory
    * It should pull the lastest version of main branch if the repo is present but not up to date, but should not modify any local changes or branches
* The script should maintain a manifest of the scripts, skills, agents, and templates that it manages to avoid interfering with any manually added ones in those locations.
  * The script should call this manifest .dev-pack and store it in the ${DEV_HOME} directory
* The script should create symlinks from the scripts directory to ${SCRIPTS_HOME} and remove the .sh extension for easier execution.
    * The script should maintain a manifest of scripts that it creates
    * The script should only manage symlinks or scripts that are in the manifest to avoid interfering with any manually added scripts in ${SCRIPTS_HOME}
    * If a script is removed from the repo, the installation script should remove the corresponding symlink from ${SCRIPTS_HOME} on the next run.
* The skills and agents should be symlinked into a location that makes it avaiable for claude and copilot to use without needing to modify their configuration.
  * Follow the same manifest and management approach as the scripts to avoid interfering with any manually added skills or agents.
  * The symlinking of skills and agents should be done in line with the expected directory structure for the coding agents to be able to find and use them without additional configuration
    * Claude suggests .claude/skills and .claude/agents in the home directory
    * Copilot suggests .copilot/skills and .copilot/agents in the home directory
  * There is no expectation that each agent will have the same symlink strategy, what is most important is that the files are not duplicated
* templates should be symlinked to the ${TEMPLATES_HOME} directory
    * Follow the same manifest and management approach as the scripts to avoid interfering with any manually added templates in ${TEMPLATES_HOME}
* The script should be idempotent and able to be run multiple times without causing issues or creating duplicate entries.

### Functional Requirements
* The script should be written in bash or zsh and be executable on a typical developer machine (Mac, Linux).
* The script should check for the presence of necessary dependencies (e.g. git)  and alert to run the local-setup script if they are missing, but should not attempt to install them itself.
* The script should be able to be run from any location and should not require being run from a specific directory.
* The script should provide clear output about what it is doing, including any errors or warnings.
* The script should be able to handle updates to the repo, including new scripts, skills, agents, or templates being added, as well as existing ones being modified or removed.
* The script should be able to be run as a hook when pulling but should also be able to be run manually without requiring a git operation.
    * The script should ask if githooks should be installed to automate this process in the future at the end of execution
    * If the githook exists when the script is run, it should not prompt to install it again and should simply ensure it is up to date with the latest version in the repo.

### Non-Functional Requirements
* The script generation should use the create_script skill in the fpm_bash_scripter directory

## Acceptance Criteria
- [ ] Skills and Agents are available to any coding agent. Note that copilot requires a configuration setting
- [ ] Templates are available in ${TEMPLATES_HOME} without needing to modify any configuration
- [ ] Scripts are symlinked to ${SCRIPTS_HOME} without needing to modify any configuration
- [ ] The script can be run multiple times without causing issues or creating duplicate entries

## Dependencies
* ${CODE_HOME}/local-setup/setup.sh should be run at least once to ensure dependencies are installed and environment variables are set.

## Notes
*
