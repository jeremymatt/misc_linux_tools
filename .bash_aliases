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

findgrep() {
    if [[ $# -lt 2 ]]; then
        echo "Usage: findgrep <dir> <pattern>" >&2
        return 2
    fi

    local dir="$1"
    local pattern="$2"

    find "$dir" 2>&1 \
    | grep -v "Permission denied" \
    | grep -- "$pattern"
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
            
            key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
            case "$key" in
                USERNAME)
                    username="$value"
                    ;;
                TOKEN)
                    token="$value"
                    ;;
                GIT_HOST)
                    git_host="$value"
                    ;;
                GIT_ACCOUNT)
                    git_account="$value"
                    ;;
            esac
        done < "$config_file"
    fi
    
    # Function to display help
    local show_help=false
    show_git_clone_usage() {
        echo "Usage: git_clone [options] <repository-name>"
        echo ""
        echo "Options:"
        echo "  -u, --username USER     Git username (overrides config file)"
        echo "  -t, --token TOKEN       Git token (overrides config file)"
        echo "  -h, --host HOST         Git host (default: gitlab.com)"
        echo "  -a, --account ACCOUNT   Git account/organization name"
        echo "  --init-config           Create a default config file at $config_file"
        echo "  --update-token          Update the remote URL for the current repository"
        echo "  --update-token-command  Print the remote update command instead of running it"
        echo "  --help                  Show this help message"
        echo ""
        echo "Config file format ($config_file):"
        echo "  USERNAME=your_git_username"
        echo "  TOKEN=your_git_token"
        echo "  GIT_HOST=gitlab.com"
        echo "  GIT_ACCOUNT=your_git_account_or_organization"
    }
    
    # Parse command-line arguments
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
            --init-config)
                if [[ -f "$config_file" ]]; then
                    echo "Config file already exists at $config_file"
                    echo "Edit it manually to change values."
                else
                    echo "Creating default config file at $config_file"
                    cat > "$config_file" << EOF
# Git Clone Configuration File
# Remove the # to uncomment and set your values

# USERNAME=your_git_username
# TOKEN=your_git_token
# GIT_HOST=gitlab.com
# GIT_ACCOUNT=your_git_account_or_organization
EOF
                    echo "Config file created. Edit $config_file with your values."
                fi
                return 0
                ;;
            --update-token|--update-token-command)
                # Determine mode: apply change or just print the command
                local print_only="false"
                if [[ "$1" == "--update-token-command" ]]; then
                    print_only="true"
                fi

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

                # Load token (and optional username) from config
                local new_token=""
                local new_username=""
                if [[ -f "$config_file" ]]; then
                    while IFS='=' read -r key value; do
                        # Skip empty lines and comments
                        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
                        key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
                        case "$key" in
                            TOKEN)
                                new_token="$value"
                                ;;
                            USERNAME)
                                new_username="$value"
                                ;;
                        esac
                    done < "$config_file"
                fi

                if [[ -z "$new_token" ]]; then
                    echo "Error: TOKEN is not set in $config_file" >&2
                    return 1
                fi

                # Parse the current URL into parts
                # Matches: https://user[:whatever]@host/path
                if [[ "$current_url" =~ ^https://([^:@]+)(:[^@]*)?@([^/]+)/(.*)$ ]]; then
                    local current_user="${BASH_REMATCH[1]}"
                    local host="${BASH_REMATCH[3]}"
                    local path="${BASH_REMATCH[4]}"
                    local final_user="${new_username:-$current_user}"

                    local new_url="https://${final_user}:${new_token}@${host}/${path}"

                    if [[ "$print_only" == "true" ]]; then
                        # Just show the command that would be run
                        echo "git remote set-url origin \"$new_url\""
                    else
                        # Update the remote URL
                        if git remote set-url origin "$new_url"; then
                            echo "Successfully updated remote origin URL with new token"
                        else
                            echo "Error: Failed to update remote URL" >&2
                            return 1
                        fi
                    fi
                else
                    echo "Error: Could not parse current remote URL format" >&2
                    echo "Current URL: $current_url" >&2
                    return 1
                fi
                return 0
                ;;
            --help)
                show_help=true
                shift
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
    
    # If help requested, display and exit
    if [[ "$show_help" == true ]]; then
        show_git_clone_usage
        return 0
    fi
    
    # Validate required parameters
    if [[ -z "$repo_name" ]]; then
        echo "Error: Repository name is required" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi
    
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







