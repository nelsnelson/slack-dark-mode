#!/usr/bin/env bash
# Usage: ./slack-dark-mode.sh [-u] for update only.
# Homebaked Slack Dark Mode.
# After executing this script restart Slack for changes to take effect.
# Adopted from https://gist.github.com/a7madgamal/c2ce04dde8520f426005e5ed28da8608

if [[ $EUID -ne 0 ]]
then
    >&2 echo "You are not root."
    >&2 echo "This script requires sudo privileges."
    exit 1
fi

print_usage() {
    echo "usage: $0 [-u] [-t <theme-css-file-path>] [-n]"
    echo "options:"
    echo " -u   Update only"
    echo " -t   The theme file css to install"
    echo " -n.  Dry-run -- show what would have been done"
}

while getopts "u:t:" opt; do
    case "$opt" in
    h)
        print_usage
        exit 0
        ;;
    u)  update=1
        ;;
    t)  theme_file_path=$OPTARG
        ;;
    n)  dryrun=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

THEME_FILE_NAME="dark-theme.css"
THEME_FILE_NAME="solarized-dark.css"
THEME_URL="https://cdn.rawgit.com/laCour/slack-night-mode/master/css/raw/black.css"
SLACK_PATH_MACOS_LOCAL="${HOME}/Applications/Slack.app"
SLACK_PATH_MACOS_SYSTEM="/Applications/Slack.app"
SLACK_PATH_LINUX="/usr/lib/slack"
EVENT_LISTENER_FILE_NAME="event-listener.js"
SLACK_VERSION="3.4.2"
UPDATE_ONLY="false"

if [[ -d $SLACK_PATH_MACOS_LOCAL ]]
then
    SLACK_PATH="${SLACK_PATH_MACOS_LOCAL}"
    SLACK_RESOURCES_PATH="${SLACK_PATH}/Contents/Resources"
elif [[ -d $SLACK_PATH_MACOS_SYSTEM ]]
then
    SLACK_PATH="${SLACK_PATH_MACOS_SYSTEM}"
    SLACK_RESOURCES_PATH="${SLACK_PATH}/Contents/Resources"
elif [[ -d $SLACK_PATH_LINUX ]]
then
    SLACK_RESOURCES_PATH="${SLACK_PATH_LINUX}/resources"
fi

if [[ ! -z `which mdls` ]]
then
    SLACK_VERSION=`mdls -raw -name kMDItemVersion $SLACK_PATH`
fi

if [[ "$1" == "-u" ]]
then
    UPDATE_ONLY="true"
fi

PACKED_APP_ASAR_PATH="$SLACK_RESOURCES_PATH/app.asar"
UNPACKED_APP_ASAR_PATH="$SLACK_RESOURCES_PATH/app.asar.unpacked"
SLACK_342_SSB_PATH="$UNPACKED_APP_ASAR_PATH/src/static/ssb-interop.js"
SLACK_400_SSB_PATH="$UNPACKED_APP_ASAR_PATH/dist/ssb-interop.bundle.js"
SLACK_THEME_PATH="$SLACK_RESOURCES_PATH/$THEME_FILE_NAME"

#curl --silent --location "${THEME_URL}" --output "${SLACK_THEME_PATH}"

if [[ "$UPDATE_ONLY" == "true" ]]; then
    echo && echo "Updating custom theme code for Slack... "
elif [[ "$UPDATE_ONLY" == "false" ]]; then
    echo && echo "Adding custom theme code to Slack... "
fi

if [[ "$1" == "--dry-run" ]]; then exit 0; fi

# Copy CSS to Slack Folder
cp -af $THEME_FILE_NAME "$SLACK_THEME_PATH"

if [[ "$UPDATE_ONLY" == "false" ]]; then
    if [[ "${SLACK_VERSION}" == "4.0.0" ]]; then
        SLACK_SSB_JS_PATH="${SLACK_400_SSB_PATH}"

        if [[ -z `which npx` ]]; then
            if [[ -z `which npm` ]]; then
                echo "Install npm: https://nodejs.org/en/"
                exit 1
            fi
            echo "Install the npm package binaries executor: npm install npx"
            exit 1
        fi

        if [[ ! -f $PACKED_APP_ASAR_PATH.bak ]]; then
            # Backup the original, packed Asar Archive for Slack
            cp -an $PACKED_APP_ASAR_PATH $PACKED_APP_ASAR_PATH.bak
        fi

        # Remove any existing unpacked Asar archive directory
        if [[ $dryrun ]]
        then
            echo "rm -rf $UNPACKED_APP_ASAR_PATH"
        else
            rm -rf $UNPACKED_APP_ASAR_PATH
        fi

        # Unpack Asar Archive for Slack
        npx asar extract $PACKED_APP_ASAR_PATH $UNPACKED_APP_ASAR_PATH

        # Add Javascript code to Slack
        tee -a "$SLACK_SSB_JS_PATH" < $EVENT_LISTENER_FILE_NAME

        # Insert the theme CSS file location in the event listener Javascript
        sed -i -e s@SLACK_DARK_THEME_PATH@$SLACK_THEME_PATH@g $SLACK_SSB_JS_PATH

        # Pack the Asar Archive for Slack
        npx asar pack $UNPACKED_APP_ASAR_PATH $PACKED_APP_ASAR_PATH

        # Remove the unpacked Asar archive directory
        rm -rf $UNPACKED_APP_ASAR_PATH
    elif [[ "${SLACK_VERSION}" == "3.4.2" ]]; then
        SLACK_SSB_JS_PATH="${SLACK_342_SSB_PATH}"

        # Backup the original, ssb-interop.js file
        cp -an $SLACK_SSB_JS_PATH $SLACK_SSB_JS_PATH.bak

        # Add Javascript code to Slack
        tee -a "$SLACK_SSB_JS_PATH" < $SLACK_EVENT_LISTENER

        # Insert the theme CSS file location in the event listener Javascript
        sed -i -e s@SLACK_DARK_THEME_PATH@$SLACK_THEME_PATH@g $SLACK_SSB_JS_PATH
    fi
fi

echo
echo "Done! After executing this script restart Slack for changes to take effect."
