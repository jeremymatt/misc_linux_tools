#!/bin/bash

git_acp() {
        git add -A
        git commit -m "$1"
        git push
}

tm() {
    if [ $# -eq 0 ]; then
        tmux ls
    else
        tmux new-session -A -s "$1"
    fi
}


alias short_prompt="export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\W\[\033[00m\]\$ '"
alias long_prompt="export PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '"

alias mount_drives="sudo mount -t drvfs V: /mnt/datanas && sudo mount -t drvfs Z: /mnt/z"
alias goto_3d="cd /mnt/d/local_working/EOD_Datahub/eod3D_pipeline"
alias goto_cs="cd /mnt/d/local_working/EOD_Datahub/circuit_sense/github/circuit-sense"

alias python='python3'



git_clone() {
    # Config file path (modify as needed)
    local config_file="$HOME/.git_clone_config"
    
    # Initialize variables with fallback defaults
    local username=""
    local token=""
    local git_host="gitlab.com"
    local git_account=""
    local repo_name=""
    
    # Load config file if it exists
    if [[ -f "$config_file" ]]; then
        # Source the config file safely
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']*//;s/["'"'"']*$//')
            
            case "$key" in
                USERNAME) username="$value" ;;
                TOKEN) token="$value" ;;
                GIT_HOST) git_host="$value" ;;
                GIT_ACCOUNT) git_account="$value" ;;
            esac
        done < "$config_file"
    else
        echo "Warning: Config file not found at $config_file" >&2
        echo "Create it with your default values or use command line flags" >&2
        echo "" >&2
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--username)
                username="$2"
                shift 2
                ;;
            -t|--token)
                token="$2"
                shift 2
                ;;
            -h|--host)
                git_host="$2"
                shift 2
                ;;
            -a|--account)
                git_account="$2"
                shift 2
                ;;
            --config)
                echo "Current config file location: $config_file"
                if [[ -f "$config_file" ]]; then
                    echo "Config file contents:"
                    # Show config but hide token value for security
                    sed 's/TOKEN=.*/TOKEN=[HIDDEN]/' "$config_file"
                else
                    echo "Config file does not exist"
                fi
                return 0
                ;;
            --init-config)
                echo "Creating example config file at $config_file"
                cat > "$config_file" << EOF
# Git Clone Configuration File
# Remove the # to uncomment and set your values

# USERNAME=your_git_username
# TOKEN=your_git_token
# GIT_HOST=gitlab.com
# GIT_ACCOUNT=your_git_account_or_organization
EOF
                echo "Config file created. Edit $config_file with your values."
                return 0
                ;;
            --update-token)
                # Check if we're in a git repository
                if ! git rev-parse --git-dir > /dev/null 2>&1; then
                    echo "Error: Not in a git repository" >&2
                    return 1
                fi
                
                # Get current remote URL
                local current_url
                current_url=$(git config --get remote.origin.url)
                
                if [[ -z "$current_url" ]]; then
                    echo "Error: No origin remote found" >&2
                    return 1
                fi
                
                # Check if current URL uses HTTPS with credentials
                if [[ ! "$current_url" =~ ^https://[^@]+@[^/]+/.+ ]]; then
                    echo "Error: Current remote URL doesn't use HTTPS with credentials format" >&2
                    echo "Current URL: $current_url" >&2
                    return 1
                fi
                
                # Load token from config
                if [[ -z "$token" ]]; then
                    echo "Error: TOKEN not set in config file $config_file" >&2
                    return 1
                fi
                
                # Extract parts from current URL
                # URL format: https://username:old_token@host/account/repo.git
                local url_pattern='^https://([^:]+):([^@]+)@(.+)$'
                if [[ "$current_url" =~ $url_pattern ]]; then
                    local url_username="${BASH_REMATCH[1]}"
                    local url_rest="${BASH_REMATCH[3]}"  # host/account/repo.git
                    
                    # Construct new URL with updated token
                    local new_url="https://${url_username}:${token}@${url_rest}"
                    
                    echo "Updating remote origin URL with new token..."
                    echo "Old URL: https://${url_username}:${BASH_REMATCH[2]}@${url_rest}"
                    echo "New URL: https://${url_username}:${token}@${url_rest}"
                    
                    # Update the remote URL
                    if git remote set-url origin "$new_url"; then
                        echo "Successfully updated remote origin URL with new token"
                    else
                        echo "Error: Failed to update remote URL" >&2
                        return 1
                    fi
                else
                    echo "Error: Could not parse current remote URL format" >&2
                    echo "Current URL: $current_url" >&2
                    return 1
                fi
                return 0
                ;;
            --help)
                echo "Usage: git_clone <REPO_NAME> [OPTIONS]"
                echo ""
                echo "Clone a git repository using username and token authentication"
                echo ""
                echo "Arguments:"
                echo "  REPO_NAME                 Repository name (required)"
                echo ""
                echo "Options:"
                echo "  -u, --username USERNAME   Git username"
                echo "  -t, --token TOKEN         Git token" 
                echo "  -h, --host HOST           Git host (default: gitlab.com)"
                echo "  -a, --account ACCOUNT     Git account/organization"
                echo "  --config                  Show current config"
                echo "  --init-config             Create example config file"
                echo "  --update-token            Update remote origin URL with token from config"
                echo "  --help                    Show this help message"
                echo ""
                echo "Configuration:"
                echo "  Config file: $config_file"
                echo "  Set USERNAME, TOKEN, GIT_HOST, and GIT_ACCOUNT in the config file"
                echo ""
                return 0
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                echo "Use --help for usage information" >&2
                return 1
                ;;
            *)
                if [[ -z "$repo_name" ]]; then
                    repo_name="$1"
                else
                    echo "Error: Multiple repository names provided" >&2
                    echo "Use --help for usage information" >&2
                    return 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if repo_name is provided
    if [[ -z "$repo_name" ]]; then
        echo "Error: Repository name is required" >&2
        echo "Usage: git_clone <REPO_NAME> [OPTIONS]" >&2
        echo "Use --help for more information" >&2
        return 1
    fi
    
    # Validate required variables
    if [[ -z "$username" ]]; then
        echo "Error: USERNAME not set. Set it in $config_file or use -u flag" >&2
        return 1
    fi
    
    if [[ -z "$token" ]]; then
        echo "Error: TOKEN not set. Set it in $config_file or use -t flag" >&2
        return 1
    fi
    
    if [[ -z "$git_account" ]]; then
        echo "Error: GIT_ACCOUNT not set. Set it in $config_file or use -a flag" >&2
        return 1
    fi
    
    # Construct and execute the git clone command
    local clone_url="https://${username}:${token}@${git_host}/${git_account}/${repo_name}.git"
    
    echo "Cloning repository: $repo_name"
    echo "From: $git_host/$git_account/$repo_name"
    
    git clone "$clone_url"
}








