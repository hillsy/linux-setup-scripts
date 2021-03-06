#==========================================================================
# Start Section: General Utility functions
#==========================================================================
function setGnomeTerminalTitle() {
    local NEW_TITLE="$1";
    PS1="[e]0;${NEW_TITLE}a]${debian_chroot:+($debian_chroot)}[033[01;32m]u@h[033[00m] [033[01;34m]w $[033[00m]";
}
function body() {
    #   https://unix.stackexchange.com/questions/11856/sort-but-keep-header-line-at-the-top
    #   print the header (the first line of input) and then pass the body (the rest of the input) back for processing on
    #   the terminal for use in a piped command etc. - e.g. $(ps | body grep somepattern) OR $(lsof -i -P -n | sort)
    IFS= read -r header
    printf '%sn' "$header"
    "$@"
}
function filePathToFileUri() {
    local filePath="$1";
    if [[ "" == "${filePath}" ]]; then
        return 500;
    fi
    local fileUri=$(echo "${filePath}" | perl -MURI::file -e 'print URI::file->new(<STDIN>)."n"');
    printf '%sn' "${fileUri}";
}
function fileUriToFilePath() {
    local fileUri="$1";
    if [[ "" == "${fileUri}" || 'file://' != "${fileUri:0:7}" ]]; then
        return 500;
    fi
    local filePath=$(perl -MURI::Escape -e 'print uri_unescape($ARGV[0])' "${fileUri:7}");
    printf '%sn' "${filePath}";
}
function getAllChecksums() {
    local checksumType="$1";
    local showHelp="false";
    local checksumArgs='';
    local aryFileList=(  );

    if (( ${#@} < 2 )); then
        showHelp="true";
    else
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            checksumType='';
            showHelp="true";
        else
            # Precheck that are args correspond to valid paths
            for (( i=2; i<=${#@}; i++ )); do
                filePath="${@:$i:1}";
                #echo "Path[${i}]: '${filePath}'";

                if [[ "-h" == "${filePath}" || "--help" == "${filePath}" ]]; then
                    showHelp="true";
                    break;

                elif [[ "-b" == "${filePath}" || "--binary" == "${filePath}" ]]; then
                    checksumArgs='--binary';
                    continue;

                elif [[ "-t" == "${filePath}" || "--text" == "${filePath}" ]]; then
                    checksumArgs='--text';
                    continue;

                elif [[ ! -e "${filePath}" ]]; then
                    echo "ERROR: Path[${i}]: '${filePath}' does not exist.";
                    return 404;

                elif [[ -f "${filePath}" ]]; then
                    # non-argument, valid single-file path
                    aryFileList+=($(realpath "${filePath}"));

                elif [[ -d "${filePath}" ]]; then
                    # https://stackoverflow.com/questions/23356779/how-can-i-store-the-find-command-results-as-an-array-in-bash/54561526#54561526
                    readarray -d '' aryFileList < <(find $(realpath "${filePath}") -type f -print0)
                fi
            done
        fi
    fi

    if [[ "true" == "${showHelp}" ]]; then
        echo 'Expected usage:';
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            echo '   getAllChecksums CHECKSUM_TYPE PATH1 [PATH2] [PATH3] [...]';
            echo '';
            echo '   CHECKSUM_TYPE   - Checksum algorithm to use: "md5", "sha1", "sha256", or "sha512"';
            echo '   PATH1/PATH2/etc - Paths to get checksums for';
        else
            echo "   getAll${checksumType^}Checksums PATH1 [PATH2] [PATH3] [...]";
            echo '';
            echo '   PATH1/PATH2/etc - Paths to get checksums for';
        fi
        echo '';
        echo 'This will generate a list of checksums sorted by path for all files under the passed paths. The checksums can be used for recursively comparing directories, single files, or any combination of the two are identical or have changed.';
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            echo "It behaves similarly to md5sum/sha256sum/etc except that it will automatically handle all recursive files under passed directories.";
        else
            echo "It behaves similarly to ${checksumType}sum except that it will automatically handle all recursive files under passed directories.";
        fi
        echo '';
        echo '  -b, --binary         read in binary mode'
        echo '  -t, --text           read in text mode (default)'
        echo '';
        return 500;
    fi

    # now collect checksums for the given paths, treating any directories recursively
    # To make sure that this is consistent regardless of where it is run from,
    # absolute path should always be used rather than relative paths
    declare -A fileChecksumMap;
    local fileChecksum='';
    for filePath in "${aryFileList[@]}"; do
        #echo "filePath: '${filePath}'";
        fileChecksum=$(${checksumType}sum ${checksumArgs} "${filePath}"| cut -d" " -f1);
        fileChecksumMap["${filePath}"]="${fileChecksum}";
    done

    local checksumLength=''
    if [[ "md5" == "${checksumType}" ]]; then
        checksumLength=32;
    elif [[ "sha1" == "${checksumType}" ]]; then
        checksumLength=40;
    elif [[ "sha256" == "${checksumType}" ]]; then
        checksumLength=64;
    elif [[ "sha512" == "${checksumType}" ]]; then
        checksumLength=128;
    fi

    # use another loop now that all values have been added to the map (and thus sorted)
    for filePath in "${!fileChecksumMap[@]}"; do
        fileChecksum="${fileChecksumMap[$filePath]}";
        #echo "key: $key";
        #echo "value: "${myMap[$key]}"";
        printf "%-${checksumLength}s  %sn" "${fileChecksum}" "${filePath}";
    done
}
function getAllMd5Checksums() {
    getAllChecksums 'md5' "${@}";
}
function getAllSha1Checksums() {
    getAllChecksums 'sha1' "${@}";
}
function getAllSha256Checksums() {
    getAllChecksums 'sha256' "${@}";
}
function getAllSha512Checksums() {
    getAllChecksums 'sha512' "${@}";
}
function getCompositeChecksum() {
    local checksumType="$1";
    local showHelp="false";
    local checksumArgs='';
    local aryFileList=(  );

    if (( ${#@} < 2 )); then
        showHelp="true";
    else
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            checksumType='';
            showHelp="true";
        else
            # Precheck that are args correspond to valid paths
            for (( i=2; i<=${#@}; i++ )); do
                filePath="${@:$i:1}";
                #echo "Path[${i}]: '${filePath}'";

                if [[ "-h" == "${filePath}" || "--help" == "${filePath}" ]]; then
                    showHelp="true";
                    break;

                elif [[ "-b" == "${filePath}" || "--binary" == "${filePath}" ]]; then
                    checksumArgs='--binary';
                    continue;

                elif [[ "-t" == "${filePath}" || "--text" == "${filePath}" ]]; then
                    checksumArgs='--text';
                    continue;

                elif [[ ! -e "${filePath}" ]]; then
                    echo "ERROR: Path[${i}]: '${filePath}' does not exist.";
                    return 404;

                elif [[ -f "${filePath}" ]]; then
                    # non-argument, valid single-file path
                    aryFileList+=($(realpath "${filePath}"));

                elif [[ -d "${filePath}" ]]; then
                    # https://stackoverflow.com/questions/23356779/how-can-i-store-the-find-command-results-as-an-array-in-bash/54561526#54561526
                    readarray -d '' aryFileList < <(find $(realpath "${filePath}") -type f -print0)
                fi
            done
        fi
    fi

    if [[ "true" == "${showHelp}" ]]; then
        echo 'Expected usage:';
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            echo '   getCompositeChecksum CHECKSUM_TYPE PATH1 [PATH2] [PATH3] [...]';
            echo '';
            echo '   CHECKSUM_TYPE   - Checksum algorithm to use: "md5", "sha1", "sha256", or "sha512"';
            echo '   PATH1/PATH2/etc - Paths to include in composite checksum';
        else
            echo "   getComposite${checksumType^} PATH1 [PATH2] [PATH3] [...]";
            echo '';
            echo '   PATH1/PATH2/etc - Paths to include in composite checksum';
        fi
        echo '';
        echo 'This will generate a cumulative checksum for the combination of all paths. The checksum can be used for recursively comparing if directories, single files, or any combination of the two are identical or have changed.';
        if [[ "md5" != "$1" && "sha1" != "$1" && "sha256" != "$1" && "sha512" != "$1" ]]; then
            echo "It behaves similarly to md5sum/sha256sum/etc except that it treats the list of files as an atomic unit and that directories are always compared recursively.";
        else
            echo "It behaves similarly to ${checksumType}sum except that it treats the list of files as an atomic unit and that directories are always compared recursively.";
        fi
        echo '';
        echo '  -b, --binary         read in binary mode'
        echo '  -t, --text           read in text mode (default)'
        echo '';
        return 500;
    fi

    # now collect checksums for the given paths, treating any directories recursively
    # To make sure that this is consistent regardless of where it is run from,
    # absolute path should always be used rather than relative paths
    declare -A fileChecksumMap;
    local fileChecksum='';
    for filePath in "${aryFileList[@]}"; do
        #echo "filePath: '${filePath}'";
        fileChecksum=$(${checksumType}sum ${checksumArgs} "${filePath}"| cut -d" " -f1);
        fileChecksumMap["${filePath}"]="${fileChecksum}";
    done

    local compositeChecksum=$(echo "${fileChecksumMap[@]}"|${checksumType}sum|cut -d" " -f1);

    printf '%sn' "${compositeChecksum}";
}
function getCompositeMd5() {
    getCompositeChecksum 'md5' "${@}";
}
function getCompositeSha1() {
    getCompositeChecksum 'sha1' "${@}";
}
function getCompositeSha256() {
    getCompositeChecksum 'sha256' "${@}";
}
function getCompositeSha512() {
    getCompositeChecksum 'sha512' "${@}";
}
function findDuplicateLinesInFile() {
    local file="$1";
    if [[ "" == "$file" || ! -f "$file" ]]; then
        echo "ERROR: No file passed or file does not exist.";
        return;
    fi

    IFS='';
    local dupeLinesArray=($(grep -Pv '^W*$' "$file" | sort | uniq -c | grep -P '^s+(d{2,}|[2-9])s+'|sed -E 's/^s*([0-9][0-9]*)s+(S+)s*$/1t2/g'));
    if [[ "0" == "${#dupeLinesArray[@]}" ]]; then
        echo "No duplicate lines detected.";
        return;
    fi
    echo "Found ${#dupeLinesArray[@]} distinct lines that occur more than once.";
    echo "";
    echo "-----------------------------------------------------------";
    echo -e "CounttText";
    echo "-----------------------------------------------------------";

    local dupeTermsArray=(  );
    for ((i = 0; i < ${#dupeLinesArray[@]}; i++)); do
        echo "${dupeLinesArray[$i]}"
        dupeTerm=$(echo "${dupeLinesArray[$i]}"|sed -E 's/^s*[0-9][0-9]*s+(.*)$/1/g');
        dupeTermsArray+=("${dupeTerm}");
    done
    unset dupeLinesArray;

    if [[ "0" != "${#dupeTermsArray[@]}" ]]; then
        echo "";
        echo "-----------------------------------------------------------";
        echo "Line Numbers:";
        echo "-----------------------------------------------------------";
        for ((i = 0; i < ${#dupeTermsArray[@]}; i++)); do
            dupeTerm="${dupeTermsArray[$i]}";
            if [[ "" == "${dupeTerm}" ]]; then
                continue;
            fi
            grep -Hn "${dupeTerm}" "${file}" 2>/dev/null;
        done
    fi
    unset dupeTermsArray;
}
function findWrapper() {
    # Default values
    local printDebugInfo="false";
    local linkOption='';
    local searchPath='.';
    local startFromArg="0";
    local typeParam='';

    # First arg = link options params (defaults to empty. can also use -P, -L, or -H; see man find for more info)
    local linkOption='';
    if [[ "" != "$1" ]]; then
        if [[ $1 =~ ^-[HLP]$ ]]; then
            linkOption="$1";
            startFromArg="1";

        elif [[ "." == "$1" || "REL" == "$1" || "RELATIVE" == "$1" ]]; then
            searchPath=".";
            startFromArg="1";

        elif [[ "~" == "${1:0:1}" ]]; then
            searchPath="${HOME}${1:1}";
            startFromArg="1";

        elif [[ "/" == "${1:0:1}" ]]; then
            searchPath="$1";
            startFromArg="1";

        elif [[ "ABS" == "$1" || "PWD" == "$1" || "FULL" == "$1" || "ABSOLUTE" == "$1" ]]; then
            if [[ -d "$1" ]]; then
                searchPath="$1";
            else
                searchPath=$(pwd);
            fi
            startFromArg="1";

        elif [[ "-dir" == "$1" ]]; then
            typeParam="-type d";
            startFromArg="1";

        elif [[ "-file" == "$1" ]]; then
            typeParam="-type f";
            startFromArg="1";
        fi
    fi

    if [[ "1" == "${startFromArg}" && "" != "$2" ]]; then
        if [[ $2 =~ ^-[HLP]$ ]]; then
            linkOption="$2";
            startFromArg="2";

        elif [[ "." == "$2" || "REL" == "$2" || "RELATIVE" == "$2" ]]; then
            searchPath=".";
            startFromArg="2";

        elif [[ "~" == "${2:0:1}" ]]; then
            searchPath="${HOME}${2:1}";
            startFromArg="2";

        elif [[ "/" == "${2:0:1}" ]]; then
            searchPath="$2";
            startFromArg="2";

        elif [[ "ABS" == "$2" || "PWD" == "$2" || "FULL" == "$2" || "ABSOLUTE" == "$2" ]]; then
            if [[ -d "$2" ]]; then
                searchPath="$2";
            else
                searchPath=$(pwd);
            fi
            startFromArg="2";

        elif [[ "-dir" == "$2" ]]; then
            typeParam="-type d";
            startFromArg="2";

        elif [[ "-file" == "$2" ]]; then
            typeParam="-type f";
            startFromArg="2";
        fi
    fi

    if [[ "2" == "${startFromArg}" && "" != "$3" ]]; then
        if [[ "-dir" == "$3" ]]; then
            typeParam="-type d";
            startFromArg="3";

        elif [[ "-file" == "$3" ]]; then
            typeParam="-type f";
            startFromArg="3";
        fi
    fi

    local hasArgs="true";
    if [[ "0" == "${startFromArg}" && "" == "$1" ]]; then
        hasArgs="false";
    elif [[ "1" == "${startFromArg}" && "" == "$2" ]]; then
        hasArgs="false";
    elif [[ "2" == "${startFromArg}" && "" == "$3" ]]; then
        hasArgs="false";
    elif [[ "3" == "${startFromArg}" && "" == "$4" ]]; then
        hasArgs="false";
    fi

    # increment by 1 (since the 0 arg will be ignored anyway - see comments below)
    startFromArg=$(( startFromArg + 1 ));

    if [[ "true" == "${printDebugInfo}" ]]; then
        echo "";
        echo "$1: $1";
        echo "$2: $2";
        echo "$3: $3";
        echo "$4: $4";
        echo "";
        echo "${@}: ${@}";
        echo "${@:0}: ${@:0}";
        echo "${@:1}: ${@:1}";
        echo "${@:2}: ${@:2}";
        echo "${@:3}: ${@:3}";
        echo "${@:4}: ${@:4}";
        echo "${@:5}: ${@:5}";
        echo "${@:6}: ${@:6}";
        echo "";
        echo "hasArgs: $hasArgs";
        echo "linkOption: $linkOption";
        echo "searchPath: $searchPath";
        echo "startFromArg: $startFromArg";
        echo "typeParam: $typeParam";
    fi

    if [[ "true" == "${hasArgs}" ]]; then
        # "${@}"   - all arguments (the zero arg, which is the function name, is omitted)
        # "${@:1}" - all arguments (the zero arg, which is the function name, is omitted)
        # "${@:2}" - all arguments except the first one
        # "${@:3}" - all arguments except the first and second ones
        find $linkOption "${searchPath}" $typeParam -not ( -wholename '*.git/*' -o -wholename '*.hg/*' -o -wholename '*.svn/*' ) "${@:${startFromArg}}" 2>/dev/null;
    else
        # There were no args besides possibly the ones for the linkOption / searchPath ...
        find $linkOption "${searchPath}" $typeParam -not ( -wholename '*.git/*' -o -wholename '*.hg/*' -o -wholename '*.svn/*' ) 2>/dev/null;
    fi
}
function findWrapperWithRelativePaths() {
    findWrapper REL "${@}";
}
function findWrapperWithAbsolutePaths() {
    findWrapper ABS "${@}";
}
function findLinkedFilesIgnoringStdErr() {
    if [[ "" == "$1" || "-" == "${1:0:1}" ]]; then
        findWrapper REL -L -file "${@}";
    else
        findWrapper REL -L -file -iname "${@}";
    fi
}
function findUnlinkedFilesIgnoringStdErr() {
    if [[ "" == "$1" || "-" == "${1:0:1}" ]]; then
        findWrapper REL -file "${@}";
    else
        findWrapper REL -file -iname "${@}";
    fi
}
function findLinkedDirsIgnoringStdErr() {
    if [[ "" == "$1" || "-" == "${1:0:1}" ]]; then
        findWrapper REL -L -dir "${@}";
    else
        findWrapper REL -L -dir -iname "${@}";
    fi
}
function findUnlinkedDirsIgnoringStdErr() {
    if [[ "" == "$1" || "-" == "${1:0:1}" ]]; then
        findWrapper REL -dir "${@}";
    else
        findWrapper REL -dir -iname "${@}";
    fi
}
function create7zArchive() {
    echo "Note: The 7z format does not perserve Linux file permissions.";
    echo "If this is desired, it is recommended to use the tar.xz format instead as";
    echo "it also uses LZMA2 compression but is able to perserve existing permissions.";
    echo "";

    local functionName="create7zArchive";
    local ext="7z";
    local firstPath="$1";

    # get the last arg as archive path
    local archivePath="";
    if (( ${#@} >= 2 )); then
        archivePath="${@:${#@}:1}";
    fi

    if [[ "" == "${firstPath}" || ! -e "${firstPath}" ]]; then
        echo "ERROR: Missing or non-existent path '$firstPath' ";
        echo "Expected usage:";
        echo "  ${functionName} /path/to/be/archived [/path2 /path3 etc] [/path/to/new/archive/file.${ext}]";
        echo "";
        echo "If the path to the new archive file is not provided or does not end with the correct file extension,";
        echo "then this will default to the first path with an appended timestamp and extension.";
        echo " e.g. '/path/to/be/archived_%Y-%m-%d@%H%M.${ext}' ";
        echo "";
        return -1;
    fi

    # check remaining paths
    if (( ${#@} > 2 )); then
        local filePath="";
        for (( i=2; i<${#@}; i++ )); do
            filePath="${@:$i:1}";
            if [[ ! -e "${filePath}" ]]; then
                echo "ERROR: Path '${filePath}' does not exist.";
                return -2;
            fi
        done
    fi

    #echo "test: ${archivePath:${#archivePath}-${#ext}-1}"
    if [[ "" == "${archivePath}" || ".${ext}" != "${archivePath:${#archivePath}-${#ext}-1}" ]]; then
        local datestr=$(date +"%Y-%m-%d@%H%M");
        archivePath="${firstPath}_${datestr}.${ext}"
    fi
    # The "${@:1:${#@}-1}" part will expand to "all passed args except the last one"
    7z a -t7z -m0=lzma2 -mx=9 -md=32m -ms=on "${archivePath}" "${@:1:${#@}-1}" >/dev/null;
    return $?;
}
function createTarArchive() {
    local compressionLevel="9";
    local functionName="createTarArchive";
    local displayHelp="false";
    local fileExt="$1";
    if [[ "" == "${fileExt}" ]]; then
        displayHelp="true";
    elif [[ "tar" != "fileExt" && ! $fileExt =~ ^tar.[bgx]z[0-9]*$ ]]; then
        echo "ERROR: Invalid output format";
        displayHelp="true";
    elif [[ "tar" != "fileExt" && $fileExt =~ ^tar.[bgx]z[0-9]$ ]]; then
        compressionLevel="${fileExt:${#fileExt}-1}";
        fileExt="${fileExt:0:${#fileExt}-1}";
        shift 1 # removes initial value of $1 from the parameter list
    else
        shift 1 # removes initial value of $1 from the parameter list
    fi
    local firstPath="$1";
    if [[ "" == "${firstPath}" || ! -e "${firstPath}" ]]; then
        echo "ERROR: Missing or non-existent path '$firstPath' ";
        displayHelp="true";
    fi

    if [[ "true" == "${displayHelp}" ]]; then
        echo "";
        echo "Expected usage:";
        echo "  ${functionName} /path/to/be/archived [/path2 /path3 etc] [/path/to/new/archive/file.${ext}]";
        echo "";
        echo "If the path to the new archive file is not provided or does not end with the correct file extension,";
        echo "then this will default to the first path with an appended timestamp and extension.";
        echo " e.g. '/path/to/be/archived_%Y-%m-%d@%H%M.${ext}' ";
        echo "";
        return -1;
    fi

    # get the last arg as archive path
    local archivePath="";
    if (( ${#@} >= 2 )); then
        archivePath="${@:${#@}:1}";
    fi

    # check remaining paths
    if (( ${#@} > 2 )); then
        local filePath="";
        for (( i=2; i<${#@}; i++ )); do
            filePath="${@:$i:1}";
            if [[ ! -e "${filePath}" ]]; then
                echo "ERROR: Path '${filePath}' does not exist.";
                return -2;
            fi
        done
    fi

    if [[ "" != "${archivePath}" ]]; then
        local requestedExtension="${archivePath:${#archivePath}-${#fileExt}-1}";
        if [[ ".${fileExt}" != "${requestedExtension}" ]]; then
            if [[ "tar" == "${fileExt}" && $archivePath =~ ^.*.tar.[7bgx]z$ ]]; then
                echo "W: Wrong function arguments; correcting to output as '${archivePath:${#archivePath}-6}' ...";
                fileExt="${archivePath:${#archivePath}-6}";
            else
                archivePath="${archivePath%.*}.${fileExt}";
                echo "W: Corrected output path to '${archivePath}' ..."|grep --color -E ".${fileExt}";
            fi
        fi
    fi

    #echo "test: ${archivePath:${#archivePath}-${#fileExt}-1}"
    if [[ "" == "${archivePath}" || ".${fileExt}" != "${archivePath:${#archivePath}-${#fileExt}-1}" ]]; then
        local datestr=$(date +"%Y-%m-%d@%H%M");
        archivePath="${firstPath}_${datestr}.${fileExt}"
    fi

    local compressionFlag="";
    case "${fileExt##*.}" in
        bz) compressionFlag="--bzip2" ;;
        gz) compressionFlag="--gzip"; GZIP_OPT=-${compressionLevel}; export GZIP_OPT; ;;
        xz) compressionFlag="--xz"; XZ_OPT=-${compressionLevel}e; export XZ_OPT; ;;
        *) compressionFlag="" ;;
    esac

    # The "${@:1:${#@}-1}" part will expand to "all passed args except the last one"
    tar --create ${compressionFlag} --preserve-permissions --file="${archivePath}" "${@:1:${#@}-1}" >/dev/null|grep -Pv 'Removing leading.*from member names';
    return $?;
}
function createTarGzArchive() {
    echo "Note: The gz format is an older format with a worse compression ratio.";
    echo "It is recommended to use tar.xz if possible.";
    echo "";
    createTarArchive 'tar.gz' "${@}";
}
function createTarXzArchive() {
    # this should default to compression level 9 (slowest but best compression)
    createTarArchive 'tar.xz' "${@}";
}
function createTarXzArchive9() {
    # use compression level 9 (slowest but best compression)
    createTarArchive 'tar.xz9' "${@}";
}
function createTarXzArchive6() {
    # use compression level 6 (default)
    createTarArchive 'tar.xz6' "${@}";
}
function createTarXzArchive3() {
    # use compression level 3 (faster)
    createTarArchive 'tar.xz3' "${@}";
}
function createTarBzArchive() {
    echo "Note: The bzip2 format is an older format with a worse compression ratio.";
    echo "It is recommended to use tar.xz if possible.";
    echo "";
    createTarArchive 'tar.bz' "${@}";
}
function makeThenChangeDir() {
    local NEW_DIR="$1";
    mkdir -p "${NEW_DIR}";
    cd "${NEW_DIR}";
}
#==========================================================================
# End Section: General Utility functions
#==========================================================================

#==========================================================================
# Start Section: Binary/Hex/Octal functions
#==========================================================================
function compareBinaries() {
    if [[ "" == "$1" || "" == "$2" ]]; then
        echo -e "ERROR: Requires two arguments.nExpected usage:nn";
        echo -e "compareBinaries binary1 binary2n";
        return;
    fi
    if [[ '' == "$(which cmp)" ]]; then
        echo -e "ERROR: compareBinaries requires cmp to work; please install and try again.";
        return;
    fi
    cmp -l "$1" "$2" | gawk '{printf "%08X %02X %02Xn", $1, strtonum(0$2), strtonum(0$3)}';
}
function diffBinaries() {
    if [[ "" == "$1" || "" == "$2" ]]; then
        echo -e "ERROR: Requires two arguments.nExpected usage:nn";
        echo -e "diffBinaries binary1 binary2n";
        return;
    fi
    if [[ '' == "$(which xxd)" || '' == "$(which diff)" ]]; then
        echo -e "ERROR: diffBinaries requires xxd and diff to work; please install and try again.";
        return;
    fi
    local tmpDir="/tmp/diffBinaries-$(date +'%Y%m%d%H%M%S')";
    mkdir -p "${tmpDir}";
    if [[ -d "${tmpDir}" ]]; then
        echo -e "diffBinaries encountered an error while creating temp dir '${tmpDir}'";
        return;
    fi
    xxd "$1" > "${tmpDir}/xxd1.hex" 2>/dev/null;
    xxd "$2" > "${tmpDir}/xxd2.hex" 2>/dev/null;
    echo '';
    diff "${tmpDir}/xxd1.hex" "${tmpDir}/xxd2.hex";
}
function getStringBlobFromBinary() {
    local file="$1";
    if [[ "" == "$file" || ! -f "$file" ]]; then
        echo "ERROR: No file passed or file does not exist.";
        return;
    fi
    local fileSizeInBytes=$(du --bytes "${file}"|cut -f1);
    hexdump -e "${fileSizeInBytes} "%_p" "\n"" "${file}";
}
function getHexBlobWithNoSpacing() {
    local file="$1";
    if [[ "" == "$file" || ! -f "$file" ]]; then
        echo "ERROR: No file passed or file does not exist.";
        return;
    fi
    local fileSizeInBytes=$(du --bytes "${file}"|cut -f1);
    hexdump -e "${fileSizeInBytes}/1 "%02x" "\n"" "${file}"
}
function getHexBlobWithSingleByteSpacing() {
    local file="$1";
    if [[ "" == "$file" || ! -f "$file" ]]; then
        echo "ERROR: No file passed or file does not exist.";
        return;
    fi
    local fileSizeInBytes=$(du --bytes "${file}"|cut -f1);
    hexdump -e "${fileSizeInBytes}/1 "%02x " "\n"" "${file}"
}
#==========================================================================
# End Section: Binary/Hex/Octal functions
#==========================================================================

#==========================================================================
# Start Section: Git functions
#==========================================================================
function gitCloneWithFormattedDir() {
    local formatPattern="$1";
    local cloneUrl="$2";
    if [[ "" == "$1" || "" == "$2" || "-h" == "$1" || "--help" == "$1" || $formatPattern =~ ^ssh:.*$ || $formatPattern =~ ^git[@:].*$ || $formatPattern =~ ^[fh]t?tps?:.*$ || ! ( 'git@github.com:' == "${cloneUrl}" || 'git@gitlab.com:' == "${cloneUrl}" || $cloneUrl =~ ^[a-zA-Z][a-zA-Z0-9]*@.*:.*/.*$ || $cloneUrl =~ ^[fh]t?tps?://.*$ || $cloneUrl =~ ^[gs][is][th]://.*$ ) ]]; then
        if [[ "" == "$1" || "" == "$2" ]]; then
            echo 'ERROR: Missing one or more arguments.';
            echo '';
        elif [[ $formatPattern =~ ^ssh:.*$ || $formatPattern =~ ^git[@:].*$ || $formatPattern =~ ^[fh]t?tps?:.*$ ]]; then
            echo 'ERROR: Invalid format pattern / incorrect argument order. The first argument should be FORMAT_PATTERN.';
            echo '';
        elif [[ ! ( 'git@github.com:' == "${cloneUrl}" || 'git@gitlab.com:' == "${cloneUrl}" || $cloneUrl =~ ^[a-zA-Z][a-zA-Z0-9]*@.*:.*/.*$ || $cloneUrl =~ ^[fh]t?tps?://.*$ || $cloneUrl =~ ^[gs][is][th]://.*$ ) ]]; then
            echo 'ERROR: Invalid clone url / incorrect argument order. The second argument should be a valid CLONE_URL.';
            echo "Note: this function does not support LOCAL clone urls";
            echo "Found: ${cloneUrl}";
            echo '';
        fi
        echo 'Expected usage:';
        echo '  gitCloneWithFormattedDir FORMAT_PATTERN CLONE_URL [OPTIONAL_ARGS]';
        echo '';
        echo 'Allows you to clone a git repository using a format pattern for the generated directory.';
        echo 'Currently only supports REMOTE clone urls (github/gitlab/bitbucket/http/https/ssh/ftp/ftps).';
        echo '';
        echo 'ARGUMENTS:';
        echo '  FORMAT_PATTERN    A format pattern to be used for the output folder that will be created.';
        echo '                    This can be relative to the current directory or prefixed with a path.';
        echo '                    See below for formatting options.';
        echo '  CLONE_URL         The clone url that will be passed to git clone';
        echo '  OPTIONAL_ARGS     Optional/arbitrary values that can be passed and referenced in the format string as %1, %2, etc';
        echo '                    Up to 9 OPTIONAL_ARGS may be passed after the clone url.';
        echo '';
        echo 'FORMATTING OPTIONS:';
        echo 'For literal percent signs, simply double them up (e.g. "This produces a literal %% symbol")';
        echo '';
        echo '  %o                Owner Name; this is taken from the clone url (e.g. https://github.com/OwnerName/RepoName)';
        echo '  %n                Repo Name; this is taken from the clone url (e.g. https://github.com/OwnerName/RepoName)';
        echo '  %1                First OPTIONAL_ARGS argument';
        echo '  %2                Second OPTIONAL_ARGS argument';
        echo '  %3                Third OPTIONAL_ARGS argument';
        echo '  %4                Fourth OPTIONAL_ARGS argument';
        echo '  %5                Fifth OPTIONAL_ARGS argument';
        echo '  %6                Sixth OPTIONAL_ARGS argument';
        echo '  %7                Seventh OPTIONAL_ARGS argument';
        echo '  %8                Eigthth OPTIONAL_ARGS argument';
        echo '  %9                Nineth OPTIONAL_ARGS argument';
        echo '';
        echo 'Examples:';
        echo $'  gitCloneWithFormattedDir '%o_%n' https://github.com/OwnerName/RepoName';
        echo '';
        return;
    fi
    shift 2;

    # note that sed does not have a non-greedy match equivalent to perl's .*?
    # there are workarounds such as https://0x2a.at/blog/2008/07/sed--non-greedy-matching/
    # but nothing simple/elegant like perl's solution
    # for max portability, we *could* cheat and just use 2 sed calls; one to trim off the .git if it exists
    # and another to work backwards from the right
    local repoName=$(echo "${cloneUrl}"|sed -E 's|^(.*).git$|1|g'|sed -E 's|.*/([^/]+)$|1|g');
    local ownerName=$(echo "${cloneUrl}"|sed -E 's|^(.*).git$|1|g'|sed -E 's|.*[:/]([^:/]+)/[^/]+$|1|g');

    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%n/\1${repoName}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%o/\1${ownerName}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%1/\1${1}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%2/\1${2}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%3/\1${3}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%4/\1${4}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%5/\1${5}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%6/\1${6}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%7/\1${7}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%8/\1${8}/g");
    formatPattern=$(echo "${formatPattern}"|sed -E "s/(^|[^%])%9/\1${9}/g");

    # Replace any doubled up percent signs with a literal percent sign
    formatPattern=$(echo "${formatPattern}"|sed -E "s/%%/%/g");

    git clone "${cloneUrl}" "${formatPattern}";
}
function gitCloneListWithFormattedDir() {
    local formatPattern="$1";
    # check remaining paths
    if (( ${#@} > 2 )); then
        local cloneUrl="";
        for (( i=2; i<${#@}; i++ )); do
            cloneUrl="${@:$i:1}";
            gitCloneWithFormattedDir "${formatPattern}" "${cloneUrl}";
        done
    fi
}
function gitArchiveLastCommit() {
    local currDir=$(pwd);
    if [[ ! -d "${currDir}/.git" ]]; then
        echo "   -> Error: Must be in top-level dir of a git repository.";
        return;
    fi
    local repoName="${currDir##*/}";
    local timeStamp=$(date +"%Y%m%d%H%M%S");
    local outFilePath="../${repoName}_${SUDO_USER:-$USER}_${timeStamp}_lastcommit.zip";
    echo "   -> outFilePath: '${outFilePath}'";
    git diff --diff-filter=CRAMX -z --name-only HEAD~1 HEAD | xargs -0 git archive HEAD -o "${outFilePath}" --;
}
function gitArchiveLastCommitBackout() {
    local currDir=$(pwd);
    if [[ ! -d "${currDir}/.git" ]]; then
        echo "   -> Error: Must be in top-level dir of a git repository.";
        return;
    fi
    local repoName="${currDir##*/}";
    local timeStamp=$(date +"%Y%m%d%H%M%S");
    local outFilePath="../${repoName}_${SUDO_USER:-$USER}_${timeStamp}_lastcommit.zip";
    echo "   -> outFilePath: '${outFilePath}'";
    git diff --diff-filter=CRAMX -z --name-only HEAD~1 HEAD | xargs -0 git archive HEAD~1 -o "${outFilePath}" --;
}
function gitArchiveAllCommitsSince() {
    local currDir=$(pwd);
    if [[ ! -d "${currDir}/.git" ]]; then
        echo "   -> Error: Must be in top-level dir of a git repository.";
        return;
    fi

    local commitOrBranchName="$1";
    if [[ "" == "${commitOrBranchName}" ]]; then
        echo "   -> Error: Must provide the name or hash value for either a commit or a branch to use as a base.";
        return;
    fi

    local displayName="${commitOrBranchName##*/}";
    displayName="${displayName//[![:alnum:]]/-}";

    local repoName="${currDir##*/}";
    local timeStamp=$(date +"%Y%m%d%H%M%S");
    local outFilePath="../${repoName}_${SUDO_USER:-$USER}_${timeStamp}_since_${displayName}.zip";
    echo "   -> outFilePath: '${outFilePath}'";
    git diff --diff-filter=CRAMX -z --name-only HEAD~1 HEAD | xargs -0 git archive HEAD -o "${outFilePath}" --;
}
function gitGrepHistoricalFileContents() {
    if [[ "" == "$1" ]]; then
        echo "gitGrepHistoricalFileContents(): No passed args.";
        echo -e "tExpected gitGrepHistoricalFileContents filename regex";
        return;
    fi
    if [[ "" == "$2" ]]; then
        echo "gitGrepHistoricalFileContents(): No passed search pattern.";
        echo -e "tExpected gitGrepHistoricalFileContents filename regex";
        return;
    fi

    git rev-list --all "$1" | (
        while read revision; do
            git grep -F "$2" $revision "$1"
        done
    )
}
function gitUpdateAllReposUnderDir() {
    local parentDir="$1";
    local startingDir=$(pwd);
    if [[ "" == "${parentDir}" ]]; then
        parentDir="${startingDir}";
    fi

    # print header - this gets printed from all logic paths so doing it once as a header up top saves space per output line
    echo "gitUpdateAllReposUnderDir():";

    # git commands must be performed relative to repo base folder
    cd "${parentDir}";

    local repoName='';
    local remoteName='';
    local remoteUrl='';

    # check if we are somewhere under a working directory in a git repo
    local repoTopLevelDir=$(git rev-parse --show-toplevel 2>/dev/null);
    if [[ "" != "${repoTopLevelDir}" ]]; then
        remoteName=$(git remote);
        if [[ "" != "${remoteName}" ]]; then
            remoteUrl=$(git remote get-url --push "${remoteName}");
        fi
        if [[ "" == "${remoteUrl}" ]]; then
            echo "  No remote fetch url found.";
            echo "  Skipping git repo: '${repoTopLevelDir}'";
            return;
        fi

        # If so, then update this single repo and exit back to terminal
        echo "  Updating git repo: '${repoTopLevelDir}'";
        echo "";

        cd "${repoTopLevelDir}";
        git fetch --all --quiet --progress;
        git pull --all --quiet --progress;

        # then change back to starting dir and return (we're all done)
        cd "${startingDir}";
        return;
    fi

    # check for permission errors
    local permErrorCount=$(find "${parentDir}" -type d -name '.git' 2>&1|grep 'Permission denied'|wc -l);
    if [[ "0" != "${permErrorCount}" ]]; then
        echo "  WARNING: Permission issues were detected for ${permErrorCount} subdirs. These subdirs will be ignored.";
        echo "  To view a list of subdirs with permission issues run:";
        echo "    find "${parentDir}" -type d -name '.git' >/dev/null";
    fi

    # otherwise, check if subfolders contain repos. if not then exit
    local totalRepos=$(find "${parentDir}" -type d -name '.git' 2>/dev/null|wc -l);
    if [[ "0" == "" ]]; then
        echo "  No git repos found for '${parentDir}'";
        echo "";
        return;
    fi

    echo "  Found ${totalRepos} git repos under:";
    echo "    '${parentDir}'";
    echo "";

    # otherwise (if there are subfolders that contain repos) then update each of the subfolder repos
    local gitdir='';
    local subdir='';
    local displaysubdir='';
    local repoCounter=0;
    local padcount=0;
    find "${parentDir}" -type d -name '.git' 2>/dev/null | while IFS='' read gitdir; do
        subdir=$(dirname "$gitdir");
        cd "${subdir}";

        repoName=$(dirname "$subdir");
        displaysubdir="$subdir";
        if [[ "${subdir:0:${#HOME}}" == "${HOME}" ]]; then
            displaysubdir="~${subdir:${#HOME}}";
        fi

        #padcount is the total number of digits to display (so it must be at least one)
        padcount=$(( 1 + ${#totalRepos} - ${#repoCounter} ));

        repoCounter=$(( 1 + repoCounter ));

        # print formatted progress info
        printf "  ==============================================================================\n";
        remoteUrl='';
        remoteName=$(git remote);
        if [[ "" != "${remoteName}" ]]; then
            remoteUrl=$(git remote get-url --push "${remoteName}");
        fi
        #printf "  subdir=%s remoteName=%s remoteUrl=%s\n" "${subdir}" "${remoteName}" "${remoteUrl}";
        if [[ "" == "${remoteUrl}" ]]; then
            printf "  No remote fetch url found.\n";
            printf "  Skipping repo %0${padcount}d of %d: %s (no remote fetch url)\n" "${repoCounter}" "${totalRepos}" "${displaysubdir}";
            continue;
        fi
        printf "  Updating repo %0${padcount}d of %d: %s\n" "${repoCounter}" "${totalRepos}" "${displaysubdir}";
        echo "";

        # call git pull in the targeted subdir
        git fetch --all --quiet --progress;
        git pull --all --quiet --progress;
    done
}
function gitListRemotesForAllReposUnderDir() {
    local parentDir="$1";
    local startingDir=$(pwd);
    if [[ "" == "${parentDir}" ]]; then
        parentDir="${startingDir}";
    fi

    # print header - this gets printed from all logic paths so doing it once as a header up top saves space per output line
    echo "gitListRemotesForAllReposUnderDir():";

    # git commands must be performed relative to repo base folder
    cd "${parentDir}";

    local repoName='';
    local remoteName='';
    local remoteUrl='';

    # check if we are somewhere under a working directory in a git repo
    local repoTopLevelDir=$(git rev-parse --show-toplevel 2>/dev/null);
    if [[ "" != "${repoTopLevelDir}" ]]; then
        printf '%-60st%sn' "${repoTopLevelDir}" $(git config --get remote.origin.url);

        # then change back to starting dir and return (we're all done)
        cd "${startingDir}";
        return;
    fi

    # check for permission errors
    local permErrorCount=$(find "${parentDir}" -type d -name '.git' 2>&1|grep 'Permission denied'|wc -l);
    if [[ "0" != "${permErrorCount}" ]]; then
        echo "  WARNING: Permission issues were detected for ${permErrorCount} subdirs. These subdirs will be ignored.";
        echo "  To view a list of subdirs with permission issues run:";
        echo "    find "${parentDir}" -type d -name '.git' >/dev/null";
    fi

    # otherwise, check if subfolders contain repos. if not then exit
    local totalRepos=$(find "${parentDir}" -type d -name '.git' 2>/dev/null|wc -l);
    if [[ "0" == "" ]]; then
        echo "  No git repos found for '${parentDir}'";
        echo "";
        return;
    fi

    echo "  Found ${totalRepos} git repos under:";
    echo "    '${parentDir}'";
    echo "";

    # otherwise (if there are subfolders that contain repos) then update each of the subfolder repos
    local gitdir='';
    local subdir='';
    local displaysubdir='';
    find "${parentDir}" -type d -name '.git' 2>/dev/null | while IFS='' read gitdir; do
        subdir=$(dirname "$gitdir");
        cd "${subdir}";

        repoName=$(dirname "$subdir");
        displaysubdir="$subdir";
        if [[ "${subdir:0:${#HOME}}" == "${HOME}" ]]; then
            displaysubdir="~${subdir:${#HOME}}";
        elif [[ "${subdir:0:${#startingDir}}" == "${startingDir}" ]]; then
            displaysubdir=".${subdir:${#startingDir}}";
        fi

        printf '%-60st%sn' "${displaysubdir}" $(git config --get remote.origin.url);
    done
}
#==========================================================================
# End Section: Git functions
#==========================================================================

#==========================================================================
# Start Section: Office file functions
#==========================================================================
function convertPdfToText() {
    local pdfFile="$1";
    if [[ ! -e "${pdfFile}" ]]; then
        echo "   -> Error: Missing or bad input file path '$pdfFile' ";
        return;
    fi
    echo "Note: This conversion is an imperfect process. It is strongly recommended to review the file and make manual revisions when complete.";

    local textFile="";
    if [[ "$2" != "" ]]; then
        textFile="$2";
    else
        textFile="${pdfFile%.*}.txt"
    fi

    pdftotext "${pdfFile}" "${textFile}";
    if [[ -e "${textFile}" ]]; then
        #1) Remove trailing spaces
        perl -pi -e 's/[ t]+$//g' "${textFile}";

        #2) Remove non-ascii characters
        perl -pi -e 's/[^[:ascii:]]//g' "${textFile}";

        #3) Convert tabs in paragraphs to spaces (perserve leading indents though)
        perl -pi -e 's/([S])[ t]+/$1 /g' "${textFile}";

        #4) Convert leading spaces to tabs (paragraph indents)
        perl -pi -e 's/^[ t]+/t/g' "${textFile}";

        #7) Convert 'form feed, new page' characters to 5x newlines
        perl -pi -e 's/^x0c/nnnnn/g' "${textFile}";
    fi
}
function convertPdfToMarkdown() {
    local pdfFile="$1";
    if [[ ! -e "${pdfFile}" ]]; then
        echo "   -> Error: Missing or bad input file path '$pdfFile' ";
        return;
    fi
    echo "Note: This conversion is an imperfect process. It is strongly recommended to review the file and make manual revisions when complete.";

    local textFile="";
    if [[ "$2" != "" ]]; then
        textFile="$2";
    else
        textFile="${pdfFile%.*}.md"
    fi

    pdftotext "${pdfFile}" "${textFile}";
    if [[ -e "${textFile}" ]]; then
        #1) Remove trailing spaces
        perl -pi -e 's/[ t]+$//g' "${textFile}";

        #2) Remove non-ascii characters
        #this was stripping out apostrophes, list bullets, and lots of other stuff...
        #probably need to specifiy exact characters that should be removed
        #perl -pi -e 's/[^[:ascii:]]//g' "${textFile}";

        #3) Convert tabs in paragraphs to spaces (perserve leading indents though)
        perl -pi -e 's/([S])[ t]+/$1 /g' "${textFile}";

        #4) Convert leading spaces to tabs (paragraph indents)
        perl -pi -e 's/^[ t]+/nt/g' "${textFile}";

        #5) Escape literal characters that would be treated as markup
        perl -0pi -e 's/\/\\/smg' "${textFile}";
        perl -0pi -e 's/([#*><[]()`|])/\$1/smg' "${textFile}";

        #6) Convert 'form feed, new page' characters to markdown 'page break' syntax
        perl -pi -e 's/^x0c/\pagen/g' "${textFile}";

        #7) Assume non-indented mixed-text, less than 35 characters is a title/heading...
        perl -pi -e 's/^([A-Z][^rn]{5,34})$/##$1/g' "${textFile}";

        #8) Assume any non-title, non-indented mixed-text is an insert line break and remove it
        perl -0pi -e 's/(n[^s#\][^rn]{40,})n([^s#\][^rn]{40,})n([^s#\])/$1 $2 $3/smg' "${textFile}";
        perl -0pi -e 's/(n[^s#\][^rn]{40,})n([^s#\][^rn]{40,})n([^s#\])/$1 $2 $3/smg' "${textFile}";
        perl -0pi -e 's/(n[^s#\][^rn]{40,})n([^s#\])/$1 $2/smg' "${textFile}";
        perl -0pi -e 's/(n[^s#\][^rn]{40,})n([^s#\])/$1 $2/smg' "${textFile}";

        #9) Same thing but for an indented line to a non-indented line
        perl -0pi -e 's/(nt+[^s#\][^rn]{40,})n([^s#\])/$1 $2/smg' "${textFile}";
    fi
}
function compressPdf() {
    local inputfile="$1";
    local arg2="$2";
    local arg3="$3";

    local outfile="${inputfile%.pdf}-compressed.pdf";
    local rvalue=150;
    if [[ "$arg2" != "" ]]; then
        outfile="$arg2";
    fi

    if [[ "$arg3" != "" ]]; then
        rvalue="$arg3";
    fi

    gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/default     -dNOPAUSE -dQUIET -dBATCH -dDetectDuplicateImages     -dCompressFonts=true -r${rvalue} -sOutputFile="${outfile}" "${inputfile}" 2>/dev/null;
}
#==========================================================================
# End Section: Office file functions
#==========================================================================

#==========================================================================
# Start Section: Media file functions
#==========================================================================
function extractMp3AudioFromVideoFile() {
    local videofile="$1";
    local bitrate="$2";
    local defbitrate="160k";
    if [[ "" == "$2" || ! $bitrate =~ ^[1-9][0-9]{1,2}k$ ]]; then
        bitrate="$defbitrate";
    fi
    local filenameonly="${videofile%.*}"
    ffmpeg -i "${videofile}" -vn -acodec libmp3lame -ac 2 -ab $bitrate -ar 48000 "${filenameonly}.mp3"
}
function extractOggAudioFromVideoFile() {
    local videofile="$1";
    local filenameonly="${videofile%.*}"
    ffmpeg -i "${videofile}" -vn -acodec libvorbis "${filenameonly}.ogg"
}
function extractMp3AudioFromAllVideosInCurrentDir() {
    local bitrate="$1";
    local defbitrate="160k";
    if [[ "" == "$1" || ! $bitrate =~ ^[1-9][0-9]{1,2}k$ ]]; then
        bitrate="$defbitrate";
    fi

    for file in *.{3gp,arf,asf,avi,f4v,flv,h264,m1v,m2v,m4v,mkv,mov,mp4,mp4v,mpg,mpeg,ogm,ogv,ogx,qt,rm,rv,wmv} ; do
        if [[ "*" == "${file:0:1}" ]]; then
            continue;
        fi
        #no clobber; skip any that already exist
        file_without_ext="${file%.*}";
        if [[ ! -f "${file_without_ext}.mp3" ]]; then
            ffmpeg -i "$file" -vn -acodec libmp3lame -ac 2 -ab $bitrate -ar 48000 "${file_without_ext}.mp3"
        fi
    done
}
function extractMp3AudioFromAllMp4InCurrentDir() {
    local bitrate="$1";
    local defbitrate="160k";
    if [[ "" == "$1" || ! $bitrate =~ ^[1-9][0-9]{1,2}k$ ]]; then
        bitrate="$defbitrate";
    fi

    for vid in *.mp4; do
        echo "vid is: $vid"
        #skip any that already exist
        if [[ ! -f "${vid%.mp4}.mp3" ]]; then
            ffmpeg -i "$vid" -vn -acodec libmp3lame -ac 2 -ab $bitrate -ar 48000 "${vid%.mp4}.mp3"
        fi
    done
}
function extractMp3AudioFromAllFlvInCurrentDir() {
    local bitrate="$1";
    local defbitrate="160k";
    if [[ "" == "$1" || ! $bitrate =~ ^[1-9][0-9]{1,2}k$ ]]; then
        bitrate="$defbitrate";
    fi

    for vid in *.flv; do
        #skip any that already exist
        if [[ ! -f "${vid%.flv}.mp3" ]]; then
            ffmpeg -i "$vid" -vn -acodec libmp3lame -ac 2 -ab $bitrate -ar 48000 "${vid%.flv}.mp3"
        fi
    done
}
function extractOggAudioFromAllMp4InCurrentDir() {
    for vid in *.mp4; do
        #skip any that already exist
        if [[ ! -f "${vid%.mp4}.ogg" ]]; then
            ffmpeg -i "$vid" -vn -acodec libvorbis "${vid%.mp4}.ogg";
        fi
    done
}
function normalizeAllOggInCurrentDir() {
    for audio_file in *.ogg; do
        normalize-ogg "${audio_file}";
    done
}
function normalizeAllMp3InCurrentDir() {
    for audio_file in *.mp3; do
        normalize-mp3 "${audio_file}";
    done
}
function getMkvAllTrackIds() {
    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   getMkvAllTrackIds /path/to/mkvfile";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi
    mkvmerge --identify "${filePath}" | grep --color=never -i Track;
}
function getMkvAudioTrackIds() {
    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   getMkvAudioTrackIds /path/to/mkvfile";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi
    mkvmerge --identify "${filePath}" | grep --color=never -i Audio;
}
function getMkvSubtitleTrackIds() {
    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   getMkvSubtitleTrackIds /path/to/mkvfile";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi
    mkvmerge --identify "${filePath}" | grep --color=never -i subtitle;
}
function getMkvSubtitleTrackInfo() {
    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   getMkvSubtitleTrackInfo /path/to/mkvfile";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi
    local rawsubinfo=$(mkvinfo --track-info "${filePath}" | grep -A 6 -B 3 "Track type: subtitles");
    if [[ "" == "$rawsubinfo" ]]; then
        return 503;
    fi
    local cleansubinfo=$(echo "$rawsubinfo" | grep -E "(Track number|Name)" | perl -0pe "s/(^|n)[s|+]+/$1/g" | perl -0pe "s/(^|n)Track number.*track ID for mkvmergeD+?(d+)[^sd]+/$1TrackID: $2/gi" | perl -0pe "s/n(Name:[^nr]+)/ $1/gi");
    echo "${cleansubinfo}";
}
function getMkvAudioTrackInfo() {
    local mkvFilePath="$1";
    if [[ "" == "$mkvFilePath" ]]; then
        echo "Expected usage:";
        echo "   getMkvAudioTrackInfo /path/to/mkvfile";
        return 501;
    elif [[ ! -f "$mkvFilePath" ]]; then
        echo "File '$mkvFilePath' does not exist.";
        return 502;
    fi
    local rawAudioInfo=$(mkvinfo --track-info "${mkvFilePath}"|grep -Pv 'Default flag|Codec|Lacing|UID|Name'|grep -B 2 "Track type: audio");
    if [[ "" == "$rawAudioInfo" ]]; then
        return 503;
    fi
    local cleanedAudioInfo=$(echo "${rawAudioInfo}" | grep -E "(Track number|Lang)" | perl -0pe "s/(^|n)[s|+]+/$1/g" | perl -0pe "s/(^|n)Track number.*track ID for mkvmergeD+?(d+)[^sd]+/$1TrackID: $2/gi" | perl -0pe "s/n(Language:[^nr]+)/ $1/gi");
    echo "${cleanedAudioInfo}";
}
function removeMkvSubtitleTracksById() {
    local makeChangesInplace="$1";
    if [[ "-i" == "${makeChangesInplace}" || $makeChangesInplace =~ ^--*inplace$ ]]; then
        makeChangesInplace="true";
        # shift remaining args once to the left
        shift;
    else
        makeChangesInplace="false";
    fi

    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   removeMkvSubtitleTracksById /path/to/mkvfile id1,id2,etc";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi

    local trackIds="$2";
    if [[ "" == "${trackIds}" || ! $trackIds =~ ^[1-9][0-9,]*$ ]]; then
        echo "removeMkvSubtitleTracksById(): ERROR empty or invalid track ids";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this method to remove one or more subtitle track ids";
        echo 'removeMkvSubtitleTracksById /path/to/file.mkv id1,id2,etc';
        return;
    fi

    local bakFile="${filePath}.bak";
    if [[ -e "${bakFile}" ]]; then
        echo "removeMkvSubtitleTracksById(): ERROR *.bak file already exists.";
        return;
    fi
    mv "${filePath}" "${bakFile}";
    mkvmerge -o "${filePath}" --subtitle-tracks !${trackIds} "${bakFile}";

    # mkvmerge doesn't actually provide an option for making changes inpace;
    # this flag just tells whether or not to keep the backup file
    if [[ "true" == "${makeChangesInplace}" ]]; then
        rm "${bakFile}" 2>/dev/null;
    fi
}
function keepMkvSubtitleTracksById() {
    local makeChangesInplace="$1";
    if [[ "-i" == "${makeChangesInplace}" || $makeChangesInplace =~ ^--*inplace$ ]]; then
        makeChangesInplace="true";
        # shift remaining args once to the left
        shift;
    else
        makeChangesInplace="false";
    fi

    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   keepMkvSubtitleTracksById /path/to/mkvfile id1,id2,etc";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi

    local trackIds="$2";
    if [[ "" == "${trackIds}" || ! $trackIds =~ ^[1-9][0-9,]*$ ]]; then
        echo "keepMkvSubtitleTracksById(): ERROR empty or invalid track ids";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this method to keep one or more subtitle track ids";
        echo 'keepMkvSubtitleTracksById /path/to/file.mkv id1,id2,etc';
        return;
    fi

    local bakFile="${filePath}.bak";
    if [[ -e "${bakFile}" ]]; then
        echo "keepMkvSubtitleTracksById(): ERROR *.bak file already exists.";
        return;
    fi
    mv "${filePath}" "${bakFile}";
    mkvmerge -o "${filePath}" --subtitle-tracks ${trackIds} "${bakFile}";

    # mkvmerge doesn't actually provide an option for making changes inpace;
    # this flag just tells whether or not to keep the backup file
    if [[ "true" == "${makeChangesInplace}" ]]; then
        rm "${bakFile}" 2>/dev/null;
    fi
}
function setMkvDefaultTrackId() {
    local makeChangesInplace="$1";
    if [[ "-i" == "${makeChangesInplace}" || $makeChangesInplace =~ ^--*inplace$ ]]; then
        makeChangesInplace="true";
        # shift remaining args once to the left
        shift;
    else
        makeChangesInplace="false";
    fi

    local filePath="$1";
    if [[ "" == "$filePath" ]]; then
        echo "Expected usage:";
        echo "   setMkvDefaultTrackId /path/to/mkvfile id";
        return 501;
    elif [[ ! -f "$filePath" ]]; then
        echo "File '$filePath' does not exist.";
        return 502;
    fi

    local defTrackId="$2";
    if [[ "" == "${defTrackId}" || ! $defTrackId =~ ^[1-9][0-9]*$ ]]; then
        echo "setMkvDefaultTrackId(): ERROR empty or invalid track id";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "# call this method to set exactly one track per track type (e.g. audio/subtitle/etc)";
        echo "# as the default track. the same method can be used to set either audio or subtitle tracks.";
        echo 'setMkvDefaultTrackId /path/to/file.mkv audioTrackId';
        echo 'setMkvDefaultTrackId /path/to/file.mkv subtitleTrackId';
        return;
    fi

    local bakFile="${filePath}.bak";
    if [[ -e "${bakFile}" ]]; then
        echo "setMkvDefaultTrackId(): ERROR *.bak file already exists.";
        return;
    fi
    mv "${filePath}" "${bakFile}";
    mkvmerge -o "${filePath}" --default-track ${defTrackId} "${bakFile}";

    # mkvmerge doesn't actually provide an option for making changes inpace;
    # this flag just tells whether or not to keep the backup file
    if [[ "true" == "${makeChangesInplace}" ]]; then
        rm "${bakFile}" 2>/dev/null;
    fi
}
function extractMkvSubtitleTextById() {
    local mkvFilePath="$1";
    if [[ "" == "$mkvFilePath" ]]; then
        echo "Expected usage:";
        echo "   extractMkvSubtitleTextById /path/to/mkvfile [trackId]";
        echo "";
        echo "If no subtitle tracj id is provided, then the first subtitle track will be used automatically.";
        return 501;
    elif [[ ! -f "$mkvFilePath" ]]; then
        echo "File '$mkvFilePath' does not exist.";
        return 502;
    fi

    local trackId="$2";
    if [[ "" == "${trackId}" ]]; then
        echo 'W: No subtitle trackId provided; looking up first subtitle track...';
        local firstSubtitleTrackId=$(mkvmerge -i "${mkvFilePath}"|grep -P '^Track ID.*subtitle'|sed -E 's/^Track ID ([1-9][0-9]*): .*subtitle.*$/1/g'|head -1);

        if [[ $firstSubtitleTrackId =~ ^[1-9][0-9]*$ ]]; then
            echo "W: Set subtitle trackId as track ${firstSubtitleTrackId}";
            trackId="${firstSubtitleTrackId}";
        fi
    fi

    if [[ "" == "${trackId}" || ! $trackId =~ ^[1-9][0-9]*$ ]]; then
        echo "extractMkvSubtitleTextById(): ERROR empty or invalid track id";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this method to remove one or more subtitle track ids";
        echo 'extractMkvSubtitleTextById /path/to/file.mkv subtitleTrackId';
        return;
    fi

    #local tmpSrt=$(date +"/tmp/%Y%m%d%H%M%S%N_$RANDOM.srt");
    #mkvextract "${mkvFilePath}" tracks "${trackId}:${tmpSrt}";
    #mv "${tmpSrt}" "${mkvFilePath%.*}.srt";
    mkvextract "${mkvFilePath}" tracks "${trackId}:${mkvFilePath%.*}.srt";
}
function addMkvSubtitleText() {
    local makeChangesInplace="$1";
    if [[ "-i" == "${makeChangesInplace}" || $makeChangesInplace =~ ^--*inplace$ ]]; then
        makeChangesInplace="true";
        # shift remaining args once to the left
        shift;
    else
        makeChangesInplace="false";
    fi

    local mkvFilePath="$1";
    if [[ "" == "$mkvFilePath" ]]; then
        echo "Expected usage:";
        echo "   addMkvSubtitleText [-i]  /path/to/file.mkv /path/to/subtitle.srt [/path/to/output-file] [subtitle track name]";
        echo "";
        echo "  -i, --inplace   makes the changes in place (e.g. in the same file without creating a backup)";
        return 501;
    elif [[ ! -f "$mkvFilePath" ]]; then
        echo "File '${mkvFilePath}' does not exist.";
        return 502;
    fi

    local srtFilePath="$2";
    if [[ "" == "$srtFilePath" ]]; then
        echo "Expected usage:";
        echo "   addMkvSubtitleText [-i] /path/to/file.mkv /path/to/subtitle.srt [/path/to/output-file]";
        return 501;
    elif [[ ! -f "$srtFilePath" ]]; then
        echo "File '${srtFilePath}' does not exist.";
        return 502;
    fi

    mkvFilePath=$(realpath "$mkvFilePath");
    srtFilePath=$(realpath "$srtFilePath");

    local outputFilePath="$3";

    local subtitleTrackName="$4";
    if [[ "" == "$subtitleTrackName" ]]; then
        subtitleTrackName="English";
    fi

    if [[ "" != "$outputFilePath" && "$outputFilePath" != "$mkvFilePath" ]]; then
        mkvmerge -o "$outputFilePath" "$mkvFilePath" --language 0:eng --track-name 0:"$subtitleTrackName" "$srtFilePath";
    else
        local bakFile="${mkvFilePath}.bak";
        if [[ -e "${bakFile}" ]]; then
            echo "addMkvSubtitleText(): ERROR *.bak file already exists.";
            return;
        fi
        mv "${mkvFilePath}" "${bakFile}";
        mkvmerge -o "$mkvFilePath" "$bakFile" --language 0:eng --track-name 0:"$subtitleTrackName" "$srtFilePath";

        # mkvmerge doesn't actually provide an option for making changes inpace;
        # this flag just tells whether or not to keep the backup file
        if [[ "true" == "${makeChangesInplace}" ]]; then
            rm "${bakFile}" 2>/dev/null;
        fi
    fi
}
function batchRemoveMkvSubtitleTracksById() {
    local folderPath="$1";
    local trackIds="$2";

    if [[ "" == "${trackIds}" && "" != "${folderPath}" && $folderPath =~ ^[0-9][0-9,]*$ ]]; then
        trackIds="${folderPath}";
        folderPath=$(pwd);
    fi

    if [[ "" == "${folderPath}" || "" == "${trackIds}" || ! $trackIds =~ ^[0-9][0-9,]*$ ]]; then
        echo "batchRemoveMkvSubtitleTracksById(): ERROR empty or invalid track ids";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this method to remove one or more subtitle track ids";
        echo 'batchRemoveMkvSubtitleTracksById /dir/with/mkvs id1,id2,etc';
        return;
    fi
    if [[ ! -e "${folderPath}" ]]; then
        echo "batchRemoveMkvSubtitleTracksById(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local options="";
    local originalLocation=$(pwd);
    cd "${folderPath}";
    for file in *mkv; do
        mv "$file" "${file}.bak";
        mkvmerge -o "$file" --subtitle-tracks !${trackIds} "${file}.bak";
        if [[ -e "${file}" ]]; then
            rm "${file}.bak";
        fi
    done
    cd "${originalLocation}";
}
function batchKeepMkvSubtitleTracksById() {
    local folderPath="$1";
    local trackIds="$2";

    if [[ "" == "${trackIds}" && "" != "${folderPath}" && $folderPath =~ ^[0-9][0-9,]*$ ]]; then
        trackIds="${folderPath}";
        folderPath=$(pwd);
    fi

    if [[ "" == "${folderPath}" || "" == "${trackIds}" || ! $trackIds =~ ^[0-9][0-9,]*$ ]]; then
        echo "batchKeepMkvSubtitleTracksById(): ERROR empty or invalid track ids";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this method to keep one or more subtitle track ids";
        echo 'batchKeepMkvSubtitleTracksById /dir/with/mkvs id1,id2,etc';
        return;
    fi
    if [[ ! -e "${folderPath}" ]]; then
        echo "batchKeepMkvSubtitleTracksById(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local originalLocation=$(pwd);
    cd "${folderPath}";
    for file in *mkv; do
        mv "$file" "${file}.bak";
        mkvmerge -o "$file" --subtitle-tracks ${trackIds} "${file}.bak";
        if [[ -e "${file}" ]]; then
            rm "${file}.bak";
        fi
    done
    cd "${originalLocation}";
}
function batchExtractMkvSubtitleTextById() {
    local folderPath="$1";
    local trackId="$2";

    if [[ "" == "${trackId}" && "" != "${folderPath}" && $folderPath =~ ^[0-9][0-9]*$ ]]; then
        trackId="${folderPath}";
        folderPath=$(pwd);
    fi

    if [[ "" == "${folderPath}" || "" == "${trackId}" || ! $trackId =~ ^[0-9][0-9]*$ ]]; then
        echo "batchExtractMkvSubtitleTextById(): ERROR empty or invalid track id";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "#call this function to extract the given subtitle track from the mkv as text (srt)";
        echo 'batchExtractMkvSubtitleTextById /dir/with/mkvs id';
        return;
    fi
    if [[ ! -e "${folderPath}" ]]; then
        echo "batchExtractMkvSubtitleTextById(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local originalLocation=$(pwd);
    cd "${folderPath}";
    for file in *mkv; do
        mkvextract "${file}" tracks "${trackId}:${file%.*}.srt";
    done
    cd "${originalLocation}";
}
function batchAddMkvSubtitleText() {
    local replaceExisting="$1";
    if [[ "-r" == "${replaceExisting}" || $replaceExisting =~ ^--*replace-existing$ ]]; then
        replaceExisting="true";
        # shift remaining args once to the left
        shift;
    else
        replaceExisting="false";
    fi

    local folderPath="$1";

    if [[ "" == "${folderPath}" || "-h" == "${folderPath}" || "--help" == "${folderPath}" ]]; then
        echo "expected usage: ";
        echo '';
        echo "# call this function to add subtitle track to the mkv";
        echo "# expects one srt per mkv and all mkv/srt pairs should have matching names"
        echo 'batchAddMkvSubtitleText /dir/with/mkvs';
        echo '';
        echo '# same as above but replace existing tracks and only keep the track being added'
        echo 'batchAddMkvSubtitleText -r /dir/with/mkvs';
        echo 'batchAddMkvSubtitleText --replace-existing /dir/with/mkvs';
        return;
    fi
    if [[ ! -e "${folderPath}" ]]; then
        echo "batchAddMkvSubtitleText(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local originalLocation=$(pwd);
    cd "${folderPath}";

    local tracksToRemove='';
    for file in *mkv; do
        # make sure the paired srt file exists, if not then skip this file
        if [[ ! -f "${file%.*}.srt" ]]; then
            continue;
        fi

        mv "$file" "${file%.*}.tmp";
        if [[ "true" == "${replaceExisting}" ]]; then
            # remove existing subtitle tracks
            tracksToRemove=$(mkvmerge -i "${file%.*}.tmp"|grep -P '^Track ID.*subtitle'|sed -E 's/^Track ID ([1-9][0-9]*): .*subtitle.*$/1/g'|tr 'n' ','|sed 's/,$//g');
            mkvmerge -o "$file" --subtitle-tracks !${tracksToRemove} "${file%.*}.tmp";
            mv "$file" "${file%.*}.tmp";
        fi
        #add the srt file
        mkvmerge -o "$file" "${file%.*}.tmp" --language 0:eng --track-name 0:English "${file%.*}.srt";
        if [[ -e "${file}" ]]; then
            rm "${file}.tmp";
        fi
    done
    cd "${originalLocation}";
}
function batchSetMkvDefaultTrackId() {
    local folderPath="$1";
    local defTrackId="$2";

    if [[ "" == "${defTrackId}" && "" != "${folderPath}" && $folderPath =~ ^[0-9][0-9]*$ ]]; then
        defTrackId="${folderPath}";
        folderPath=$(pwd);
    fi

    if [[ "" == "${defTrackId}" || ! $defTrackId =~ ^[1-9][0-9]*$ ]]; then
        echo "batchSetMkvDefaultTrackId(): ERROR empty or invalid track ids";
        echo "expected usage: ";
        echo "#get list of subtitle track ids";
        echo 'getMkvSubtitleTrackInfo';
        echo '';
        echo "# call this method to set exactly one track per track type (e.g. audio/subtitle/etc)";
        echo "# as the default track. the same method can be used to set either audio or subtitle tracks.";
        echo 'batchSetMkvDefaultTrackId /path/to/folder audioTrackId';
        echo 'batchSetMkvDefaultTrackId /path/to/folder subtitleTrackId';
        return;
    fi

    if [[ ! -e "${folderPath}" ]]; then
        echo "batchSetMkvDefaultTrackId(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local originalLocation=$(pwd);
    cd "${folderPath}";
    for file in *mkv; do
        mv "$file" "${file}.bak";
        mkvmerge -o "${file}" --default-track ${defTrackId} "${file}.bak";
        if [[ -e "${file}" ]]; then
            rm "${file}.bak";
        fi
    done
    cd "${originalLocation}";
}
function batchLogMkvSubtitleTrackInfo() {
    local outputFileName="SUBTITLES_INFO.txt";
    local folderPath="$1";

    if [[ "" == "${folderPath}" ]]; then
        folderPath=$(pwd);

    elif [[ "-h" == "${folderPath}" || $folderPath =~ ^--*help$ ]]; then
        echo "batchLogMkvSubtitleTrackInfo(): ERROR empty dir";
        echo "expected usage: ";
        echo "#output a list of subtitle track ids to ${outputFileName}";
        echo 'batchLogMkvSubtitleTrackInfo /dir/with/mkvs';
        return;
    fi
    if [[ ! -e "${folderPath}" ]]; then
        echo "batchLogMkvSubtitleTrackInfo(): ERROR mkv parent folder does not exist.";
        return;
    fi
    local originalLocation=$(pwd);
    local SEPARATOR="------------------------------------";
    cd "${folderPath}";
    for file in *mkv; do
        echo -e "n${SEPARATOR}n${file}n${SEPARATOR}n" >> "${outputFileName}";

        local rawsubinfo=$(mkvinfo --track-info "${file}" | grep -A 6 -B 3 "Track type: subtitles");
        if [[ "" == "$rawsubinfo" ]]; then
            echo -e "t -> No subs detected." >> "${outputFileName}";
            continue;
        fi
        local cleansubinfo=$(echo "$rawsubinfo" | grep -E "(Track number|Name)" | perl -0pe "s/(^|n)[s|+]+/$1/g" | perl -0pe "s/(^|n)Track number.*track ID for mkvmergeD+?(d+)[^sd]+/$1TrackID: $2/gi" | perl -0pe "s/n(Name:[^nr]+)/ $1/gi");

        echo "${cleansubinfo}" >> "${outputFileName}";
    done
    cd "${originalLocation}";
}
#==========================================================================
# End Section: Media file functions
#==========================================================================

#==========================================================================
# Start Section: Wine functions
#==========================================================================
function createNewWine32Prefix() {
    if [[ "" == "$1" ]]; then
        echo -e "ERROR: Requires argument.nExpected usage:nn";
        echo -e "createNewWine32Prefix folder-to-be-createdn";
        echo -e "Note:  the new prefix folder must not exist yet.";
        return;
    elif [[ -e "$1" ]]; then
        echo -e "ERROR: Path already exists; wine will not create a new prefix at an existng location.nExpected usage:nn";
        echo -e "createNewWine32Prefix folder-to-be-createdn";
        echo -e "Note:  the new prefix folder must not exist yet.";
        return;
    fi
    env WINEPREFIX="$1" WINEARCH=win32 wine wineboot
}
function createNewWine64Prefix() {
    if [[ "" == "$1" ]]; then
        echo -e "ERROR: Requires argument.nExpected usage:nn";
        echo -e "createNewWine64Prefix folder-to-be-createdn";
        echo -e "Note:  the new prefix folder must not exist yet.";
        return;
    elif [[ -e "$1" ]]; then
        echo -e "ERROR: Path already exists; wine will not create a new prefix at an existng location.nExpected usage:nn";
        echo -e "createNewWine64Prefix folder-to-be-createdn";
        echo -e "Note:  the new prefix folder must not exist yet.";
        return;
    fi
    env WINEPREFIX="$1" WINEARCH=win64 wine wineboot
}
function winetricksHere() {
    local foundValidWinePrefix='false';
    local startingDir=$(pwd);
    local winePrefixDir="${startingDir}";
    if [[ -d  "${winePrefixDir}/drive_c" ]]; then
        foundValidWinePrefix='true';
    else
        while [[ "false" == "${foundValidWinePrefix}" ]]; do
            if [[ -d  "${winePrefixDir}/drive_c" ]]; then
                foundValidWinePrefix='true';
                break;
            fi
            winePrefixDir=$(dirname "${winePrefixDir}");
            if [[ "/" == "${winePrefixDir}" || "" == "${winePrefixDir}" ]]; then
                break;
            fi
        done;
    fi
    if [[ "false" == "${foundValidWinePrefix}" ]]; then
        echo -e "ERROR: winetricksHere - Not under a valid WINEPREFIX folder.";
        return;
    fi
    env WINEPREFIX="${winePrefixDir}" winetricks $1 $2 $3 $4 $5 $6 $7 $8 $9
}
function runWineCommandHere() {
    local wineCommand="$1";
    local functionName="runWineCommandHere";
    if [[ "" == "${wineCommand}" ]]; then
        echo "ERROR: runWineCommandHere - no args";
        return;
    fi
    if [[ "" != "$2" ]]; then
        functionName="$2";
    fi

    local foundValidWinePrefix='false';
    local startingDir=$(pwd);
    local winePrefixDir="${startingDir}";
    if [[ -d  "${winePrefixDir}/drive_c" ]]; then
        foundValidWinePrefix='true';
    else
        while [[ "false" == "${foundValidWinePrefix}" ]]; do
            if [[ -d  "${winePrefixDir}/drive_c" ]]; then
                foundValidWinePrefix='true';
                break;
            fi
            winePrefixDir=$(dirname "${winePrefixDir}");
            if [[ "/" == "${winePrefixDir}" || "" == "${winePrefixDir}" ]]; then
                break;
            fi
        done;
    fi
    if [[ "false" == "${foundValidWinePrefix}" ]]; then
        echo -e "ERROR: ${functionName} - Not under a valid WINEPREFIX folder.";
        return;
    fi
    env WINEPREFIX="${winePrefixDir}" wine ${wineCommand};
}
function wineCmdHere() {
    runWineCommandHere 'cmd' 'wineCmdHere'
}
function wineConfigHere() {
    runWineCommandHere 'winecfg' 'wineConfigHere'
}
function wineRegeditHere() {
    runWineCommandHere 'regedit' 'wineRegeditHere'
}
function goToWinePrefix() {
    local foundValidWinePrefix='false';
    local startingDir=$(pwd);
    local winePrefixDir="${startingDir}";
    if [[ -d  "${winePrefixDir}/drive_c" ]]; then
        foundValidWinePrefix='true';
    else
        while [[ "false" == "${foundValidWinePrefix}" ]]; do
            if [[ -d  "${winePrefixDir}/drive_c" ]]; then
                foundValidWinePrefix='true';
                break;
            fi
            winePrefixDir=$(dirname "${winePrefixDir}");
            if [[ "/" == "${winePrefixDir}" || "" == "${winePrefixDir}" ]]; then
                break;
            fi
        done;
    fi
    if [[ "false" == "${foundValidWinePrefix}" ]]; then
        echo -e "ERROR: goToWinePrefix - Not under a valid WINEPREFIX folder.";
        return;
    fi
    cd "${winePrefixDir}";
}
function printWinePrefix() {
    local foundValidWinePrefix='false';
    local startingDir=$(pwd);
    local winePrefixDir="${startingDir}";
    if [[ -d  "${winePrefixDir}/drive_c" ]]; then
        foundValidWinePrefix='true';
    else
        while [[ "false" == "${foundValidWinePrefix}" ]]; do
            if [[ -d  "${winePrefixDir}/drive_c" ]]; then
                foundValidWinePrefix='true';
                break;
            fi
            winePrefixDir=$(dirname "${winePrefixDir}");
            if [[ "/" == "${winePrefixDir}" || "" == "${winePrefixDir}" ]]; then
                break;
            fi
        done;
    fi
    if [[ "false" == "${foundValidWinePrefix}" ]]; then
        echo -e "ERROR: printWinePrefix - Not under a valid WINEPREFIX folder.";
        return;
    fi
    echo "${winePrefixDir}";
}
#==========================================================================
# End Section: Wine functions
#==========================================================================

#==========================================================================
# Start Section: Administration functions
#==========================================================================
function runCommandAsUser() {
    if [[ "" == "$1" || "" == "$2" ]]; then
        echo "usage:";
        echo "  runCommandAsUser USER COMMAND";
        echo "";
        echo "  If the command consists of arguments or otherwise";
        echo "  contains spaces, then it must be enclosed in quotes.";
        return;
    fi

    # "${@:2}" - all arguments except the first one
    su - "$1" -c "${@:2}"
}
function checkBIOSType() {
    if [[ -e /sys/firmware/efi ]]; then
        echo "OS has been booted using UEFI.";
    else
        echo "OS has been booted using Legacy BIOS.";
    fi
}
function makeBackupWithTimestamp() {
    local defaultTsFormat="%Y%m%d%H%M%S";
    local defaultDelim=".";
    local defaultBakFormat="%p${defaultDelim}%t${defaultDelim}%b";
    local maxDescLength=40;

    local targetPath="$1";
    local tsFormat="$2";
    local bakFormat="$3";
    local shortDesc="$4";
    local showUsage='false';
    if [[ "" == "${targetPath}" ]]; then
        echo "ERROR: No arguments.";
        showUsage='true';
    else
        if [[ "-h" == "${targetPath}" || "--help" == "${targetPath}" ]]; then
            showUsage='true';
        elif [[ ! -e "${targetPath}" ]]; then
            echo "ERROR: Path does not exist.";
            echo "  passed path: '${targetPath}'";
            showUsage='true';
        elif [[ -L "${targetPath}" ]]; then
            echo "ERROR: Path is a link.";
            showUsage='true';
        fi
    fi
    if [[ "true" == "${showUsage}" ]]; then
        echo "";
        echo "Expected usage:";
        echo "makeBackupWithTimestamp SOURCE_PATH";
        echo "makeBackupWithTimestamp SOURCE_PATH [tsFormat] [backupFormat] [desc]";
        echo "";
        echo "This will create a backup of the indicated path at: ";
        echo " '${SOURCE_PATH}.yyyymmdd.HHMMSS.bak'";
        echo "";
        echo "SOURCE_PATH:  path to a file or a folder.";
        echo "   NOTE: Links are not supported.";
        echo "";
        echo "tsFormat:     timeformat for /bin/date";
        echo "   defaults to '${defaultTsFormat}'";
        echo "";
        echo "backupFormat: format for backup name, as follows:";
        echo "   %p - source path";
        echo "   %t - timestamp";
        echo "   %d - short description";
        echo "   %b - the bak extension (does not include dot)";
        echo "";
        echo "   defaults to '${defaultBakFormat}'";
        echo "";
        echo "desc:         short description of ${maxDescLength} chars or less.";
        echo " The description text can only contain alphanum, dot, plus, minus, and equals characters.";
        echo "";
        return;
    fi

    # check if the current user has write perms for a file or folder
    # https://askubuntu.com/questions/980658
    if [[ ! -w "${targetPath}" ]]; then
        # user does not own a file then
        # get sudo prompt out of the way before other messaging
        sudo ls -acl 2>/dev/null >/dev/null;
    fi

    # check backup name format
    if [[ "" == "${bakFormat}" ]]; then
        bakFormat="${defaultBakFormat}";
    elif [[ $bakFormat =~ ^.*[^-A-Za-z0-9.+=_%].*$ ]]; then
        # bad format; clear it and let it use default
        echo "Warning: Backup name format contains invalid characters; falling back to default."
        bakFormat="${defaultBakFormat}";
    else
        # when dealing with paths that contain more than just filename
        # require that %p must be used AND must appear only at the start
        if [[ $targetPath =~ ^.*/.*$ ]]; then
            if [[ ! $bakFormat =~ ^%p.*$ || $bakFormat =~ ^..*%p.*$ ]]; then
                # bad format; clear it and let it use default
                echo "Warning: The passed source path contains /; In this case,the Backup name format must use %p and it must appear at the start of the pattern; falling back to default."
                bakFormat="${defaultBakFormat}";
            fi
        fi
        local testPattern=$(printf "%s" "${bakFormat}.%d"|sed 's/%[bdtp]//g');
        if [[ $testPattern =~ ^.*%.*$ ]]; then
            # bad format; clear it and let it use default
            echo "Warning: Backup name format contains invalid % escape sequences; falling back to default."
            bakFormat="${defaultBakFormat}";
        fi
    fi
    # check timestamp format
    if [[ "" != "${tsFormat}" ]]; then
        tsFormat=$(date +"${tsFormat}");
        if [[ "0" != "$?" || $tsFormat =~ ^.*[^-A-Za-z0-9.+=_].*$ ]]; then
            # bad format; clear it and let it use default
            echo "Warning: Bad timestamp format; falling back to default."
            tsFormat="";
        fi
    fi
    # set default timestamp format if none defined
    if [[ "" == "${tsFormat}" ]]; then
        tsFormat="${defaultTsFormat}";
    fi
    # check short description for spaces, invalid chars, length
    if [[ "" != "${shortDesc}" ]]; then
        if [[ $shortDesc =~ ^.*[^-.+=_A-Za-z0-9].*$ ]]; then
            shortDesc=$(printf "${shortDesc}"|sed 's/s+/-/g'|sed 's/[^-.+=_A-Za-z0-9]+//g');
        fi
        if (( ${#shortDesc} > $maxDescLength )); then
            shortDesc="${shortDesc:0:$maxDescLength}";
        fi
    fi
    local timeStamp=$(date +"${tsFormat}");

    # build backup name from pattern
    local backupPath=$(printf "%s" "${bakFormat}"|sed 's/%b/bak/g'|sed "s/%t/${timeStamp}/g");
    if [[ "" != "${shortDesc}" && $backupPath =~ ^.*%d.*$ ]]; then
        backupPath=$(printf "%s" "${backupPath}"|sed "s/%d/${shortDesc}/g");
    fi
    if [[ "%p" == "${backupPath:0:2}" ]]; then
        backupPath="${targetPath}${backupPath:2}";
    elif [[ $backupPath =~ ^.*%p.*$ ]]; then
        backupPath=$(printf "%s" "${backupPath}"|sed "s|%p|${targetPath}|g");
    fi

    # validate backup path
    if [[ $backupPath =~ ^.*%.*$ ]]; then
        echo "ERROR: backupPath contains unexpanded strings.";
        echo "   backupPath: '${backupPath}'";
        echo "";
        echo "Aborting function call ...";
        return;
    fi
    if [[ -e "${backupPath}" ]]; then
        echo "ERROR: backupPath already exists...";
        echo "   backupPath: '${backupPath}'";
        echo "";
        echo "Aborting function call ...";
        return;
    fi

    echo "Creating backup at: '${backupPath}' ...";
    # check if the current user has write perms for a file or folder
    # https://askubuntu.com/questions/980658
    if [[ ! -w "${targetPath}" ]]; then
        # user does not write perms for a file then
        sudo cp -a --no-clobber "${targetPath}" "${backupPath}";
    else
        cp -a --no-clobber "${targetPath}" "${backupPath}";
    fi
    if [[ "0" == "$?" ]]; then
        echo "-> SUCCESS";
    else
        echo "-> FAILURE";
    fi
}
function makeBackupWithDateOnly() {
    local path="$1";
    local bakFmt="$2";
    local comment="$3";
    if [[ "" == "${comment}" ]]; then
        makeBackupWithTimestamp "$path" '%Y%m%d' '%p-%t.%b';
    else
        makeBackupWithTimestamp "$path" '%Y%m%d' '%p-%t-%d.%b' "${comment}";
    fi
}
function makeBackupWithFullTimestamp() {
    local path="$1";
    local bakFmt="$2";
    local comment="$3";
    if [[ "" == "${comment}" ]]; then
        makeBackupWithTimestamp "$path" '%Y%m%d%H%M%S' '%p-%t.%b';
    else
        makeBackupWithTimestamp "$path" '%Y%m%d%H%M%S' '%p-%t-%d.%b' "${comment}";
    fi
}
function makeDirMine() {
    local FN_NAME="makeDirMine";
    local TARGET_DIR="$1";
    local RECURSIVE="false";
    if [[ "" != "$2" ]]; then
        if [[ "-R" == "$1" || "-r" == "$1" || "--recursive" == "$1" ]]; then
            TARGET_DIR="$2"
            RECURSIVE="true";
        elif [[ "-R" == "$2" || "-r" == "$2" || "--recursive" == "$2" ]]; then
            RECURSIVE="true";
        fi;
    fi
    if [[ "" == "${TARGET_DIR}" ]]; then
        echo "${FN_NAME}: ERROR: Missing target dir. Exiting function...";
        return;
    fi
    if [[ ! -e "${TARGET_DIR}" ]]; then
        echo "${FN_NAME}: ERROR: ${TARGET_DIR} does not exist. Exiting function...";
        return;
    fi
    if [[ "true" == "${RECURSIVE}" ]]; then
        sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "${TARGET_DIR}";
    else
        sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "${TARGET_DIR}";
    fi
}
function makeDirMineNonRecursively() {
    makeDirMine "$1";
}
function makeDirMineRecursively() {
    makeDirMine -R "$1";
}
function makeDirOnlyMineNonRecursively() {
    makeDirMine "$1";
    sudo chmod o-rwx "$1";
}
function makeDirOnlyMineRecursively() {
    makeDirMine -R "$1";
    sudo chmod -R o-rwx "$1";
}
#==========================================================================
# End Section: Administration functions
#==========================================================================

#==========================================================================
# Start Section: Housekeeping functions
#==========================================================================
function cleanBashHistory() {
    local stfu="false";
    if [[ "-q" == "$1" || "--quiet" == "$1" || "--stfu" == "$1" ]]; then
        stfu="true";
    fi
    if [[ "false" == "${stfu}" ]]; then
        echo "Cleaning up ~/.bash_history ... ";
    fi

    local hostName=$(hostname);

    # cleanup trivial commands from history
    # run as multiple passes to clean adjacent lines better...
    for i in {1..250}; do
        local lineCountBefore=$(cat "$HOME/.bash_history"|wc -l);

        # 1. remove dead SAFE (simple no- and one-arg) commands/function calls/typos/alias/etc
        # note: the second regex group was constructed to avoid removal of 'update-grub'
        sed -i -z -E 's/n(agrep|apt search|cat|echo|getent|git|groups|id|kill|killall|ls?|man|md5sum|members|nmblookup|p[gks]|pgrep|pkill|printf|shad+sum|sudo|sudo apt|title|which)? ?(;|c;s|w+|w[-w]{1,9}|w[-w]{11,}|w+-[^g]w+|~?/[-w/]+)s*(&|-h|--help|--version)?s*n/n/g' "$HOME/.bash_history";

        # 2. remove dead SAFE (simple no- and one-arg) SUDO commands/function calls/typos/alias/etc
        sed -i -z -E 's/n(sudo)? ?apt(-get)? (--help|autoremove|dist-upgrade|list --upgrade?able|update) ?-?y?s*(2>s*&1|2>s*/dev/null)?s*(>s*/dev/null)?s*;?s*n/n/g' "$HOME/.bash_history";

        # 3. remove any references to data files
        sed -i -z -E 's/n[^n]*/media/[-w]+/(data|Media|Backups)b[^n]*n/n/g' "$HOME/.bash_history";

        # 4. remove any references to media files
        sed -i -z -E 's/n[^n]*.(avi|epub|ogg|m4[ab]|mkv|mobi|mp[34gv]|srt)b[^n]*n/n/g' "$HOME/.bash_history";

        # 5. remove somewhat safe commands/function calls/typos/alias/etc
        sed -i -z -E 's/n(sudo )?(arp|basename|basedir|branch|cat|commit|date|df|diff|dirname|dpkg -L|dpkg-query|du|echo|git|[asp]?grep|gthumb|head|inxi|ip|p?kill|killall|ldd|locate|ls?|lsmkvsubs|md5sum|merge|nmblookup|p[gk]|ping|printf|ps|rename|rmdirmkvsubs|shad+sum|tail|title|tree|uname|youtube-dl|ytdl)b [^n|>]*s*(2>s*&1|2>s*/dev/null)?s*(>s*/dev/null)?s*n/n/g' "$HOME/.bash_history";

        # 6. remove somewhat safe single-piped commands
        sed -i -z -E 's/n(arp|basename|basedir|cat|date|df|diff|dirname|dpkg -L|dpkg-query|du|find|echo|git|[asp]?grep|head|history|inxi|ip|ldd|locate|ls?|lsgroups|lsusers|man|md5sum|mostspace|nmblookup|p[gk]|ping|printf|ps|shad+sum|tail|tree|uname)b(|| [^n|>]*|)s*b(grep|head|sed|sort|tail|wc|xargs)b s*[^n|>]*n/n/g' "$HOME/.bash_history";

        # 7. remove simple find commands (nothing with exec or delete)
        sed -i -z -E "s/\n\b(f|ff|fd|find [~\.]?\/[-\/\w]*)\b( \-m[ai][nx]depth \d+)?( \-m[ai][nx]depth \d+)?( \-type [fdl]| \-iname)? ["']?[^\n"\|'\s]*["']?\s*\n/\n/g" "$HOME/.bash_history";

        # 8. remove simple debug statements
        sed -i -z -E 's/n[^n]*becho "(bar|crap|debug|damn|dammit|foo|foobar|fuck|grr+|shit|test)";[^n]*n/n/gi' "$HOME/.bash_history";

        # 9. remove any lines with personal info
        sed -i -z -E "s/\n[^\n]*(\bssh\b|\b${USER}\b|\b${hostName}\b|login|password|w*PWD=|w*USE?R=|d+.d+.d+.d+)[^\n]*\n/\n/gi" "$HOME/.bash_history";

        local lineCountAfter=$(cat "$HOME/.bash_history"|wc -l);
        # if we get done earlier, then quit earlier
        if [[ "${lineCountBefore}" == "${lineCountAfter}" ]]; then
            break;
        fi
        if [[ "false" == "${stfu}" ]]; then
            echo "  -> completed pass $i: ${lineCountBefore} lines -> $ ${lineCountAfter}";
        fi
    done;
}
function backupAndCleanBashHistory() {
    cp -a "$HOME/.bash_history" "$HOME/.bash_history."$(date +'%Y%m%d%H%M%S').bak;
    cleanBashHistory "${@}";
}
#==========================================================================
# End Section: Housekeeping functions
#==========================================================================

#==========================================================================
# Start Section: Hard Drive functions
#==========================================================================
function displayFstabDiskMountpoints() {
    #determine mount points as defined in /etc/fstab
    local mntpnts=$(awk -F'\s+' '/^(UUID|/dev/).*/ {print $2}' /etc/fstab|tr 'n' '|');

    #remove trailing delim
    mntpnts="${mntpnts:0:${#mntpnts}-1}";

    # display disk mount points from df but filter to only things defined in fstab
    echo "Mounted fstab partitions from df -h:";
    echo "==========================================";
    df -h|grep -P "^.*(${mntpnts})$"|grep -Pv '^(tmpfs|/dev/loop|udev|/dev/sr0)';
}
function displayNonFstabDiskMountpoints() {
    #determine mount points as defined in /etc/fstab
    local mntpnts=$(awk -F'\s+' '/^(UUID|/dev/).*/ {print $2}' /etc/fstab|tr 'n' '|');

    #remove trailing delim
    mntpnts="${mntpnts:0:${#mntpnts}-1}";

    # display disk mount points from df but filter out anything defined in fstab
    echo "Mounted non-fstab partitions from df -h:";
    echo "==========================================";
    # display disk mount points from df but filter out anything defined in fstab
    df -h|grep -Pv "^.*(${mntpnts})$"|grep -Pv '^(tmpfs|/dev/loop|udev|/dev/sr0)';

    echo "";
    echo "USB disks detected under /dev/disks/by-id:";
    echo "==========================================";
    ls -gG /dev/disk/by-id/|grep usb|awk -F' ' '{print $9"t"$7}'|sed 's/^../..//dev/';
}
function printAndSortByAvailableDriveSpace() {
    local sep="============================================================";
    echo -e "${sep}nDrive Space as of "$(date +'%a, %b %d @ %H:%M:%S')"n${sep}nFilesystem      Size  Used Avail Use% Mounted on";

    # sort no suffix first (e.g. corresponds to bytes)
    df -h | grep -Pv '(/dev/loop|tmpfs|udev|/dev/sr0)'|awk -F'\s+' '$4~/^([0-9][.0-9]*)$/ {print $0}'|sort -k4 -n

    # sort suffixes in increasing order
    local suffixOrder="K M G T";
    for suffix in $suffixOrder; do
        df -h | grep -Pv '(/dev/loop|tmpfs|udev|/dev/sr0)'|awk -F'\s+' "$4~/^([0-9][.0-9]*${suffix})$/ {print $0}"|sort -k4 -n;
    done
}
function printAndSortByMountPoint() {
    local sep="============================================================";
    echo -e "${sep}nDrive Space as of "$(date +'%a, %b %d @ %H:%M:%S')"n${sep}nFilesystem      Size  Used Avail Use% Mounted on";

    df -h | grep -Pv '(/dev/loop|tmpfs|udev|/dev/sr0)'|awk -F'\s+' '$4~/^([0-9].*)$/ {print $0}'|sort -k6;
}
function mountAllFstabEntries() {
    # first make sure all the auto mount stuff is mounted
    # this also doubles as a way to get the sudo prompt out
    # of the way up front
    sudo mount --all;
    sleep 1s;

    local fstabMountPointsArray=($(awk -F'\s+' '/^s*[^#].*/media/.*$/ {print $2}' /etc/fstab));
    local activeMountsArray=($(mount | awk -F'\s+' '/^.*/media/.*$/ {print $3}'));
    local isAlreadyMounted="false";

    # now check for everything else; at this point it
    # should just be the entries with noauto
    for mountPoint in "${fstabMountPointsArray[@]}"; do
        isAlreadyMounted="false";
        for activeMount in "${activeMountsArray[@]}"; do
            if [[ "${activeMount}" == "${mountPoint}" ]]; then
                # set flag
                isAlreadyMounted="true";

                # exit inner loop
                break;
            fi
        done
        if [[ "true" == "${isAlreadyMounted}" ]]; then
            # already mounted; skip to next fstab entry
            continue;
        fi
        #echo "Attempting to mount ${mountPoint}";
        sudo mount "${mountPoint}" 2>/dev/null;
    done
}
function printDriveAndPartitionInfo() {
    # declare maps
    declare -A partitionToUUIDMap;
    declare -A partitionToLabelMap;
    declare -A partitionToTypeMap;
    declare -A UUIDtoMountPointMap;
    declare -A partitionToMountPointMap;
    declare -A partitionToTotalSizeMap;
    declare -A partitionToFreeSpaceeMap;
    declare -A partitionToUsedSpaceMap;
    declare -A hardDiskToModelMap;
    declare -A hardDiskToSizeMap;

    # get map of device path to hard drive model
    eval $(sudo parted --list --machine 2>/dev/null|grep -Pv 'BYT|sr0|^$|^d'|gawk -F: '{print $1" ""$7"""}'|sort -u|xargs -n 2 sh -c 'echo "hardDiskToModelMap["$1"]="$2""' argv0);

    # get map of device path to hard drive size
    eval $(eval echo $(sudo parted --list --machine 2>/dev/null|grep -Pv 'BYT|sr0|^$|^d'|gawk -F: '{print $1" "$2}'|sed -E 's/([1-9][0-9]{3})GB/$(printf "%0.2f\n" $(echo "1/1024"|bc -l))TB/g')|xargs -n 2 sh -c 'echo "hardDiskToSizeMap["$1"]="$2""' argv0);

    # get map of device paths to UUIDs
    eval $(sudo blkid|grep -P '^/dev/sd[a-z].*UUID'|sed -E 's|(/dev/sd[a-z][1-9]):.*s+UUID=("[^"]+").*$|1 2|g'|sed -E 's|(/dev/sd[a-z][1-9]):.*s+PARTUUID=("[^"]+").*$|1 2|g'|sort -u|xargs -n 2 sh -c 'echo "partitionToUUIDMap["$1"]="$2""' argv0);

    # get map of device paths to partition types
    eval $(sudo blkid|grep -P '^/dev/sd[a-z].*TYPE'|sed -E 's|(/dev/sd[a-z][1-9]):.*s+TYPE=("[^"]+").*$|1 2|g'|sort -u|xargs -n 2 sh -c 'echo "partitionToTypeMap["$1"]="$2""' argv0);

    # get map of device paths to partition labels
    eval $(sudo blkid|grep -P '^/dev/sd[a-z].*LABEL'|sed -E 's|(/dev/sd[a-z][1-9]):.*s+LABEL=("[^"]+").*$|1 2|g'|sed -E 's|(/dev/sd[a-z][1-9]):.*s+PARTLABEL=("[^"]+").*$|1 2|g'|sort -u|xargs -n 2 sh -c 'echo "partitionToLabelMap["$1"]="$2""' argv0);

    # get map of device paths to mount points
    eval $(df -h|gawk -F'\s+' '$1 ~ /^/dev/sd[a-z][1-9]$/ {print $1" "$6}'|sort -u|xargs -n 2 sh -c 'echo "partitionToMountPointMap["$1"]="$2""' argv0);

    # get map of device paths to total partition size
    eval $(eval echo $(sudo parted --list --machine 2>/dev/null|grep -Pv 'BYT|sr0'|sed -Ez 's|n(/dev/sd[a-z])([1-9]?:[^n]+)n([1-9]:[^/n]+)n([1-9]:[^/n]+)n|n12n13n14n|g'|grep -Pv 'BYT|sr0'|sed -Ez 's|n(/dev/sd[a-z])([1-9]?:[^n]+)n([1-9]:[^/n]+)n([1-9]:[^/n]+)n|n12n13n14n|g'|sed -Ez 's|n?(/dev/sd[a-z])([1-9]?:[^n]+)n([1-9]:[^/n]+)n|n12n13n|g'|sed -Ez 's|n?(/dev/sd[a-z])([1-9]?:[^n]+)n([1-9]:[^/n]+)n|n12n13n|g'|sed '/^$/d'|sed -E 's/^(/dev/sdw:[^:]+):.*:(gpt|msdos):([^:]+):.*$/1:2:3/g'|grep -P '/dev/sdw[1-9]:'|sed -E 's/^(/dev/sdw[1-9]):[^:]+:[^:]+:([^:]+):.*$/1:2/g'|sed -E 's/([1-9][0-9]{3})GB/$(printf "%0.2f\n" $(echo "1/1024"|bc -l))T/g'|sed -E 's/([1-9][0-9]{3})kB/$(printf "%0.1f\n" $(echo "1/1024"|bc -l))M/g'|sed -E 's/([GM])B$/1/g')|tr ':' ' '|xargs -n 2 sh -c 'echo "partitionToTotalSizeMap["$1"]="$2""' argv0);
    eval $(df -h|gawk -F'\s+' '$1 ~ /^/dev/sd[a-z][1-9]$/ {print $1" "$2}'|sort -u|xargs -n 2 sh -c 'echo "partitionToTotalSizeMap["$1"]="$2""' argv0);

    # get map of device paths to free space
    eval $(df -h|gawk -F'\s+' '$1 ~ /^/dev/sd[a-z][1-9]$/ {print $1" "$4}'|sort -u|xargs -n 2 sh -c 'echo "partitionToFreeSpaceeMap["$1"]="$2""' argv0);

    # get map of device paths to used space
    eval $(df -h|gawk -F'\s+' '$1 ~ /^/dev/sd[a-z][1-9]$/ {print $1" "$3}'|sort -u|xargs -n 2 sh -c 'echo "partitionToUsedSpaceMap["$1"]="$2""' argv0);

    # get maps of uuid to mount points
    eval $(gawk -F'\s+' '$1 ~ /^UUID=/ {print $1" "$2}' /etc/fstab|sort -u|xargs -n 2 sh -c 'echo "UUIDtoMountPointMap["$1"]="$2""' argv0);

    # print entries
    local diskDevicePath='';
    local diskModel='';
    local diskCapacity='';
    local partitionDevicePath='';
    local uuid='';
    local label='';
    local fstype='';
    local mountPoint='';
    local totalSize='';
    local freeSpace='';
    local usedSpace='';

    for diskDevicePath in "${!hardDiskToModelMap[@]}"; do
        diskModel="${hardDiskToModelMap[$diskDevicePath]}";
        diskCapacity="${hardDiskToSizeMap[$diskDevicePath]}";

        echo "";
        echo "===============================================================================================";
        printf '%s Drive "%s" at %sn' "${diskCapacity}" "${diskModel}" "${diskDevicePath}";
        echo "===============================================================================================";
        printf '%st%st%st%st%st%-22st%sn' 'Filesystem' 'Type' 'Size' 'Used' 'Avail' 'Label' 'Mounted on'
        for i in {1..9}; do
            partitionDevicePath="${diskDevicePath}${i}";
            uuid="${partitionToUUIDMap[$partitionDevicePath]}";
            if [[ "" == "${uuid}" ]]; then
                continue;
            fi

            label="${partitionToLabelMap[$partitionDevicePath]}";
            fstype="${partitionToTypeMap[$partitionDevicePath]}";
            mountPoint="${partitionToMountPointMap[$partitionDevicePath]}";
            totalSize="${partitionToTotalSizeMap[$partitionDevicePath]}";
            freeSpace="${partitionToFreeSpaceeMap[$partitionDevicePath]}";
            usedSpace="${partitionToUsedSpaceMap[$partitionDevicePath]}";

            if [[ "" == "${mountPoint}" ]]; then
                mountPoint="${UUIDtoMountPointMap[$uuid]}";
            fi
            if [[ "" == "${mountPoint}" ]]; then
                mountPoint="<not mounted>";
            fi
            if [[ "Microsoft reserved partition" == "${label}" ]]; then
                label="Microsoft Reserved";
            fi
            printf '%st%st%st%st%st%-22st%sn' "${partitionDevicePath}" "${fstype}" "${totalSize}" "${usedSpace}" "${freeSpace}" "${label:0:18}" "${mountPoint}";
        done
    done
}
function checkFileNamesValidForWindows() {
    local parentDir="$1";
    if [[ "" == "${parentDir}" || ! -d "${parentDir}" ]]; then
        echo "ERROR: checkFileNamesValidForWindows(): Expected path to folder containing files to be checked.";
        return 501;
    fi

    local startingDir=$(pwd);
    echo "=======================================================================";
    echo "Checking for invalid Windows filenames under: ";
    echo "  '${parentDir}' ";
    echo "=======================================================================";

    cd "${parentDir}";

    printf 'nChecking for Invalid Characters ... ';
    printf 'Found %s occurrences: n' $(LC_ALL=C find . -name '*[:<>?|"*]*' -o -name '**' -o -name '*[! -~]*' | wc -l);
    # https://unix.stackexchange.com/questions/109747/identify-files-with-non-ascii-or-non-printable-characters-in-file-name
    # https://www.asciitable.com/
    LC_ALL=C find . -name '*[:<>?|"*]*' -o -name '**' -o -name '*[! -~]*' | sort;

    printf 'nChecking for Invalid Spacing ... ';
    printf 'Found %s leading spaces and %s trailing spaces: n' $(LC_ALL=C find . -iregex '^.*/ .*$' -o -iregex '^.* /.*$'|wc -l) $(LC_ALL=C find . -type f -iregex '^.* .[A-Za-z0-9][A-Za-z0-9]*'|wc -l);
    LC_ALL=C find . -iregex '^.*/ .*$' -o -iregex '^.* /.*$'|sort;
    LC_ALL=C find . -type f -iregex '^.* .[A-Za-z0-9][A-Za-z0-9]*'|sort;

    # Ignore starting path because e.g. '/media/myusb-drive' would, under Windows,
    # be mounted as e.g. 'F:'. Length should be calculated as:
    # A) Absolute Path (e.g. '/media/myusb-drive/foo.txt'), minus the
    #       parent path (e.g. '/media/myusb-drive'), plus 2 (letter + colon)
    # OR more simply:
    # B) Relative unix path (e.g. './media/myusb-drive/foo.txt'), minus one (leading dot),
    #   plus 2 (letter + colon)
    # OR even more simply
    # C) Relative unix path (e.g. './media/myusb-drive/foo.txt'),
    #   plus 1 (letter + colon minus the leading dot from unix relative path)
    #
    # SO we can start with the "Max Windows Path (Under FAT)" as 255
    # then subtract 1 (254) to find the Max Relative Path size under unix
    # that will successfully work on a FAT partition.
    # Then add one to (255) find paths that are too long.

    printf 'nChecking for Path Length ... ';
    printf 'Found %s paths that are too long for FAT partitions (max 255 chars*): n' $(LC_ALL=C find .|grep -Pc '^.{255,}$');
    LC_ALL=C find .|grep -P '^.{255,}$'|sort

    printf 'nn*Note: this includes the drive letter and colon added by Windows.nn';

    cd "${startingDir}";

}
function removeInvalidCharactersFromFileNames() {
    local typeList='d f';
    local separator='=========================================================';

    declare -A windowsInvalidCharactersMap;
    windowsInvalidCharactersMap["""]="s/"//g";
    windowsInvalidCharactersMap[":"]="s/://g";
    windowsInvalidCharactersMap["[?]"]="s/[?]//g";
    windowsInvalidCharactersMap["[*]"]="s/[*]//g";
    windowsInvalidCharactersMap[">"]="s/>//g";
    windowsInvalidCharactersMap["<"]="s/<//g";
    windowsInvalidCharactersMap["[\\]"]="s/[\\]//g";
    windowsInvalidCharactersMap["[|]"]="s/[|]//g";
    windowsInvalidCharactersMap["[`]"]="s/[`]/'/g";

    local typeName='';
    printf '%sn%sn%sn' "${separator}" "Checking for invalid Windows characters:" "${separator}";
    for type in $typeList; do
        #echo "type: $type";
        if [[ 'd' == "${type}" ]]; then
            typeName='Dir';
        else
            typeName='File';
        fi

        for invalidCharacter in "${!windowsInvalidCharactersMap[@]}"; do
            #echo "invalidCharacter: $invalidCharacter";
            replacePattern="${windowsInvalidCharactersMap[$invalidCharacter]}";
            #echo "replacePattern: $replacePattern";

            printf '%s: Checking for character %s in name ... n' "${typeName}" "'${invalidCharacter}'";
            find . -type ${type} -iname "*${invalidCharacter}*" -exec prename "${replacePattern}" "{}" ; 2>/dev/null;
        done

        # moving this one outside the loop as it can sometimes cause issues when bash interprets as a non-literal character
        printf '%s: Checking for exclaimation point character in name ... n' "${typeName}";
        find . -type ${type} -iname '*!*' -exec prename 's/!//g' "{}" ; 2>/dev/null;
    done

    declare -A unicodeCharactersReplacementMap;
    unicodeCharactersReplacementMap["¡"]="s/¡//g";
    unicodeCharactersReplacementMap["«"]="s/«/[/g";
    unicodeCharactersReplacementMap["®"]="s/®//g";
    unicodeCharactersReplacementMap["™"]="s/™//g";
    unicodeCharactersReplacementMap["´"]="s/´/'/g";
    unicodeCharactersReplacementMap["»"]="s/»/]/g";
    unicodeCharactersReplacementMap["¿"]="s/¿//g";
    unicodeCharactersReplacementMap["ß"]="s/ß/ss/g";
    unicodeCharactersReplacementMap["à"]="s/à/a/g";
    unicodeCharactersReplacementMap["á"]="s/á/a/g";
    unicodeCharactersReplacementMap["â"]="s/â/a/g";
    unicodeCharactersReplacementMap["ä"]="s/ä/a/g";
    unicodeCharactersReplacementMap["å"]="s/å/a/g";
    unicodeCharactersReplacementMap["è"]="s/è/e/g";
    unicodeCharactersReplacementMap["é"]="s/é/e/g";
    unicodeCharactersReplacementMap["ê"]="s/ê/e/g";
    unicodeCharactersReplacementMap["ë"]="s/ë/e/g";
    unicodeCharactersReplacementMap["í"]="s/í/i/g";
    unicodeCharactersReplacementMap["ï"]="s/ï/i/g";
    unicodeCharactersReplacementMap["ñ"]="s/ñ/n/g";
    unicodeCharactersReplacementMap["ó"]="s/ó/o/g";
    unicodeCharactersReplacementMap["ô"]="s/ô/o/g";
    unicodeCharactersReplacementMap["Ö"]="s/Ö/O/g";
    unicodeCharactersReplacementMap["ö"]="s/ö/o/g";
    unicodeCharactersReplacementMap["Ø"]="s/Ø/0/g";
    unicodeCharactersReplacementMap["ú"]="s/ú/u/g";
    unicodeCharactersReplacementMap["ü"]="s/ü/u/g";
    unicodeCharactersReplacementMap["ō"]="s/ō/o/g";
    unicodeCharactersReplacementMap["й"]="s/й/n/g";
    unicodeCharactersReplacementMap["к"]="s/к/k/g";
    unicodeCharactersReplacementMap["о"]="s/о/o/g";
    unicodeCharactersReplacementMap["п"]="s/п/n/g";
    unicodeCharactersReplacementMap["ґ"]="s/ґ/r/g";
    unicodeCharactersReplacementMap["–"]="s/\s*–\s*/ - /g";
    unicodeCharactersReplacementMap["–"]="s/\s*–\s*/ - /g";
    unicodeCharactersReplacementMap["‘"]="s/‘/'/g";
    unicodeCharactersReplacementMap["’"]="s/’/'/g";
    unicodeCharactersReplacementMap["…"]="s/…/ /g";
    unicodeCharactersReplacementMap["…"]="s/…/ /g";
    unicodeCharactersReplacementMap["“"]="s/“//g";
    unicodeCharactersReplacementMap["”"]="s/”//g";

    printf '%sn%sn%sn' "${separator}" "Checking for unicode characters:" "${separator}";
    for type in $typeList; do
        #echo "type: $type";
        if [[ 'd' == "${type}" ]]; then
            typeName='Dir';
        else
            typeName='File';
        fi

        for unicodeCharacter in "${!unicodeCharactersReplacementMap[@]}"; do
            #echo "unicodeCharacter: $unicodeCharacter";
            replacePattern="${unicodeCharactersReplacementMap[$unicodeCharacter]}";
            #echo "replacePattern: $replacePattern";

            printf '%s: Checking for unicode character %s in name ... n' "${typeName}" "'${unicodeCharacter}'";
            find . -type ${type} -iname "*${unicodeCharacter}*" -exec prename "${replacePattern}" "{}" ; 2>/dev/null;
        done

        printf '%s: Replacing all other misc unicode characters in name ... n' "${typeName}";
        ALL=C find . -type ${type} -name '*[! -~]*' -exec prename 's/[^ -~]//g' "{}" ; 2>/dev/null;
    done

    printf '%sn%sn%sn' "${separator}" "Checking for leading/trailing spaces:" "${separator}";
    for type in $typeList; do
        #echo "type: $type";
        if [[ 'd' == "${type}" ]]; then
            typeName='Dir';
        else
            typeName='File';
        fi

        printf '%s: Checking for leading spaces/dots/underscores in name ... n' "${typeName}";
        find . -type ${type} -iregex '^.*/[. _][^/]*$' -exec prename 's/^(.*/)[s_.]+(.+)$/$1$2/g' "{}" ; 2>/dev/null;

        printf '%s: Checking for trailing spaces/dots/underscores in name ... n' "${typeName}";
        find . -type ${type} -name '*[. _]' -exec prename 's/^(.+[^s_.])[s_.]+$/$1/g' "{}" ; 2>/dev/null;
    done
    # and for trailing spaces/dots/underscores BEFORE the file extension
    find . -type f -name '*[. _].*' -exec prename 's/^(.+[^s_.])[s_.]+(.w+)$/$1$2/g' "{}" ; 2>/dev/null;
}
#==========================================================================
# End Section: Hard Drive functions
#==========================================================================

#==========================================================================
# Start Section: Network functions
#==========================================================================
function getGbUsedThisSession() {
    local ethernetInterface=$(ifconfig 2>/dev/null|grep -P '^ew+:'|head -1|sed -E 's/^(ew+):s.*$/1/g');
    local ethernetBytes=$(cat "/sys/class/net/${ethernetInterface}/statistics/rx_bytes");
    local vpnBytes=$(cat "/sys/class/net/tun0/statistics/rx_bytes");
    local totalBytes=$(echo "${ethernetBytes} + ${vpnBytes}"|bc -l)
    local totalGB=$(printf "%.2f" $(echo "${totalBytes} / 1024 / 1024 / 1024 "|bc -l));

    echo "Total GB used since PC was started: ${totalGB} GB";
}
function isValidIpAddr() {
    # return code only version
    local ipaddr="$1";
    [[ ! $ipaddr =~ ^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$ ]] && return 1;
    for quad in $(echo "${ipaddr//./ }"); do
        (( $quad >= 0 && $quad <= 255 )) && continue;
        return 1;
    done
}
function validateIpAddr() {
    # return code + output version
    local ipaddr="$1";
    local errmsg="ERROR: $1 is not a valid IP address";
    [[ ! $ipaddr =~ ^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$ ]] && echo "$errmsg" && return 1;
    for quad in $(echo "${ipaddr//./ }"); do
        (( $quad >= 0 && $quad <= 255 )) && continue;
        echo "$errmsg";
        return 1;
    done
    echo "SUCCESS: $1 is a valid IP address";
}
function mountWindowsNetworkShare() {
    local networkPath="$1";
    local mountPoint="$2";
    local remoteLogin="$3";
    local remotePassword="$4";

    # validate input
    local showUsage="false";
    if [[ "-h" == "$1" || "--help" == "$1" ]]; then
        showUsage="true";

    elif [[ "" == "${networkPath}" ]]; then
        echo "ERROR: REMOTE_PATH is empty";
        showUsage="true";

    elif [[ "" == "${mountPoint}" ]]; then
        echo "ERROR: LOCAL_PATH is empty";
        showUsage="true";

    elif [[ ! $mountPoint =~ ^[~.]?/.*$ || $mountPoint =~ ^//.*$ ]]; then
        echo "ERROR: LOCAL_PATH must be a valid local path";
        showUsage="true";

    elif [[ "" == "${remoteLogin}" ]]; then
        echo "ERROR: REMOTE_USER is empty";
        showUsage="true";

    elif [[ "" == "${remotePassword}" ]]; then
        echo "ERROR: REMOTE_PWD is empty";
        showUsage="true";
    fi

    # secondary validations
    if [[ "false" == "${showUsage}" ]]; then
        # get sudo prompt out of the way
        sudo ls -acl 2>/dev/null >/dev/null;

        # canonicalize network path
        if [[ "//" != "${networkPath:0:2}" ]]; then
            networkPath="//${networkPath}";
        fi

        # Make sure network path is of the format:
        #   HOST/SHARE
        #
        # Where REMOTE_HOST is either a valid HOST or a valid IP_ADDR
        local remoteHost=$(printf "${networkPath}"|sed -E 's|^//([^/]+)/.*$|1|g');
        local shareName=$(printf "${networkPath}"|sed -E 's|^//[^/]+/(.*)$|1|g');

        if [[ "${#networkPath}" == "${#remoteHost}" || "0" == "${#remoteHost}" || "${#networkPath}" == "${#shareName}" || "0"  == "${#shareName}" ]]; then
            echo "ERROR: REMOTE_PATH is invalid. It should be in the form: //IPADDR/SHARE_NAME";
            showUsage="true";

        elif [[ $shareName =~ ^.*[^-A-Za-z0-9_.+= ~%@#()&].*$ ]]; then
            echo "ERROR: REMOTE_PATH is invalid. shareName '${shareName}' contains invalid characters.";
            showUsage="true";

        elif [[ $remoteHost =~ ^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$ ]]; then
            # definitely *supposed* to be an ip address
            # check if it is a *valid* ip address (correct numerical ranges)

            # check that each ip quad is with the range 0 to 255
            isValidIpAddr "$remoteHost";
            if [[ "0" != "$?" ]]; then
                echo "ERROR: REMOTE_PATH is invalid. host '${remoteHost}' is not a valid ip address.";
                showUsage="true";
            fi

        elif [[ $remoteHost =~ ^[A-Za-z][-A-Za-z0-9_.]*$ ]]; then
            # host names are only allowed if the system supports
            # resolving hostnames...
            local supportsHostNameResolution="true";
            if [[ ! -f /etc/nsswitch.conf ]]; then
                echo "WARNING: Missing /etc/nsswitch.conf; will not be able to resolve Windows host names...";
                supportsHostNameResolution="false";
            else
                local winbindPkgCount=$(apt search winbind | grep -P "^is+(winbind|libnss-winbind)s+"|wc -l);
                if (( $winbindPkgCount < 2 )); then
                    echo "WARNING: Missing winbind / libnss-winbind packages; will not be able to resolve Windows host names...";
                    supportsHostNameResolution="false";
                fi
            fi

            if [[ "false" == "${supportsHostNameResolution}" ]]; then
                echo "ERROR: REMOTE_PATH is invalid; system doesn't support resolution of named host '${remoteHost}'.";
                echo "";
                echo "Use IP address instead or update system to support host name resolution.";
                echo "See:";
                echo "   https://www.techrepublic.com/article/how-to-enable-linux-machines-to-resolve-windows-hostnames/";
                echo "   https://askubuntu.com/a/516533/1003652";
                showUsage="true";

                echo "";
                echo "Attempting to resolve for next time ...";
                sudo apt-get install -y winbind libnss-winbind 2>/dev/null >/dev/null;
            else
                local unresolvedHostChk=$(ping -c 1 "$remoteHost" 2>&1 | grep 'Name or service not known'|wc -l);
                if [[ "0" == "${unresolvedHostChk}" ]]; then
                    echo "ERROR: REMOTE_PATH is invalid; system was unable to resolve named host '${remoteHost}'.";
                    echo "";
                    echo "Use IP address instead or update system to support host name resolution.";
                fi
            fi
        fi
    fi

    if [[ "true" == "${showUsage}" ]]; then
        echo "";
        echo "Expected usage:";
        echo "mountWindowsNetworkShare REMOTE_PATH LOCAL_PATH REMOTE_USER REMOTE_PWD";
        echo "";
        echo "Mounts the indicated path, if it is not already mounted.";
        echo "";
        echo "REMOTE_PATH must be in the form: //IPADDR/SHARE_NAME";
        echo "";
        echo "LOCAL_PATH  must be a valid local path.";
        echo "";
        echo "REMOTE_USER should be the user name on the remote machine. If it contains spaces, pass in quotes.";
        echo "";
        echo "REMOTE_PWD should be the user password on the remote machine. This should always be passed in quotes. Additionally, special characters should be preceded by a backslash (\) when using double-quotes. Especially:";
        echo " * dollar sign ($)";
        echo " * backslash (\)"
        echo " * backtick (`)";
        echo " * double-quote (")";
        echo " * exclaimation mark (!)";
        echo " * all special characters may be escaped but the above are required.";
        echo "";
        return;
    fi

    local isAlreadyMounted=$(mount|grep -P "${mountPoint}"|wc -l);
    if [[ "0" != "${isAlreadyMounted}" ]]; then
        echo "'${mountPoint}' is already mounted."
        return;
    fi

    if [[ ! -e "${mountPoint}" ]]; then
        sudo mkdir "${mountPoint}";
        sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "${mountPoint}";
    fi
    echo "Attempting to mount '${networkPath}' at '${mountPoint}' ...";
    sudo mount -t cifs "${networkPath}" "${mountPoint}" -o "user=${remoteLogin},username=${remoteLogin},password=${remotePassword},dir_mode=0777,file_mode=0777";
    if [[ "0" == "$?" ]]; then
        echo "-> SUCCESS";
    else
        echo "-> FAILURE";
    fi
}
function unmountWindowsNetworkShare() {
    local mountPoint="$1";

    # validate input
    if [[ "" == "${mountPoint}" ]]; then
        echo "ERROR: local mountPoint is empty";
        echo "Expected usage:";
        echo "unmountWindowsNetworkShare /local/path/to/mount/point";
        echo "";
        echo "   unmounts the indicated path, if it is mounted.";
        echo "";
        return;
    fi

    # check if mounted
    local isAlreadyMounted=$(mount|grep -P "${mountPoint}"|wc -l);
    if [[ "0" == "${isAlreadyMounted}" ]]; then
        echo "'${mountPoint}' is not currently mounted."
        return;
    fi
    echo "Attempting to unmount '${mountPoint}' ...";
    sudo umount --force "${mountPoint}";
    if [[ "0" == "$?" ]]; then
        echo "-> SUCCESS";
    else
        echo "-> FAILURE";
    fi
}
function displayGatewayIp() {
    ip r|grep default|sed -E 's/^.*b([0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3})b.*$/1/g';
}
function displayNetworkHostnames() {
    local gatewayIp=$(ip r|grep default|sed -E 's/^.*b([0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3})b.*$/1/g');

    echo -e "IP AddresstHostname";
    local ipAddr='';
    for ipAddr in $(arp -vn|grep -P '^d'|grep -Pv "\b(${gatewayIp})\b" |awk -F'\s+' '{print $1}'); do
        local hostName=$(nmblookup -A "${ipAddr}"|grep -Pvi '(Looking|No reply|<GROUP>|MAC Address)'|grep -i '<ACTIVE>'|head -1|sed -E 's/^s+(S+)s*.*$/1/');
        echo -e "${ipAddr}t${hostName}";
    done
}
#==========================================================================
# End Section: Network functions
#==========================================================================

#==========================================================================
# Start Section: Package Management functions
#==========================================================================
function whichRealBinary() {
    if [[ "" == "$1" || "-h" == "$1" || "--help" == "$1" ]]; then
        echo "Expected usage";
        echo "   whichRealBinary binaryName";
        echo "or whichRealBinary pathToBinary";
        echo "";
        echo "Similar to which but it will display the following additional information:";
        echo " * file type (file or symlink)";
        echo " * if the file is a symlink, the real path will be displayed.";
        echo "";
        echo "  binaryName   - Name of a binary on $PATH such as 7z, curl, firefox, etc";
        echo "  pathToBinary - Path to a binary installed by a package. This can be the path of an actual file (e.g. /usr/bin/7z) or a symlink to an actual file (e.g. /usr/bin/vi); however either the resolved file must be part of a package.";
        echo "";
        return 0;
    fi
    local path="$1";
    if [[ "~/" == "${path:0:2}" ]]; then
        path="$HOME/${path:2}";
    elif [[ "./" == "${path:0:2}" ]]; then
        path="$PWD/${path:2}";
    fi

    # if path is really just a name, try looking it up
    # using which
    if [[ $path =~ ^[A-Za-z0-9][-A-Za-z0-9._+]*$ ]]; then
       local binLocation=$();
        if [[ "" != "${binLocation}" && -e "${binLocation}" ]]; then
            local realLoc="${binLocation}";
            local type="file";
            if [[ -L "${binLocation}" ]]; then
                realLoc=$(realpath "${binLocation}");
                type="symlink";
            fi
            echo "${realLoc}";
        fi
    fi
}
function whichPackage() {
    if [[ "" == "$1" || "-h" == "$1" || "--help" == "$1" ]]; then
        echo "Expected usage";
        echo "   whichPackage binaryName";
        echo "or whichPackage pathToBinary";
        echo "";
        echo "Finds what package a binary is from (e.g. /usr/bin/7z => p7zip-full)";
        echo "  binaryName   - Name of a binary on $PATH such as 7z, curl, firefox, etc";
        echo "  pathToBinary - Path to a binary installed by a package. This can be the path of an actual file (e.g. /usr/bin/7z) or a symlink to an actual file (e.g. /usr/bin/vi); however either the resolved file must be part of a package.";
        echo "";
        return 0;
    fi
    local path="$1";
    if [[ "~/" == "${path:0:2}" ]]; then
        path="$HOME/${path:2}";
    elif [[ "./" == "${path:0:2}" ]]; then
        path="$PWD/${path:2}";
    fi

    # if path is really just a name, try looking it up
    # using which
    if [[ $path =~ ^[A-Za-z0-9][-A-Za-z0-9._+]*$ ]]; then
        local binLocation=$(which "${path}" 2>/dev/null);
        if [[ "" != "${binLocation}" && -e "${binLocation}" ]]; then
            local realLoc="${binLocation}";
            if [[ -L "${binLocation}" ]]; then
                realLoc=$(realpath "${binLocation}");
            fi
            path="${realLoc}";
        fi
    fi
    dpkg -S "${path}"|awk -F: '{print $1}';
}
function whichBinariesInPackage() {
    if [[ "" == "$1" || "-h" == "$1" || "--help" == "$1" ]]; then
        echo "Expected usage";
        echo "   whichBinariesInPackage packageName";
        echo "";
        echo "Find out which binaries are in a package (e.g. p7zip-full => /usr/bin/7z)";
        echo "  packageName   - Name of a package to find binaries for such as p7zip-full, curl, firefox, etc";
        echo "";
        return 0;
    fi
    local beVerbose="false";
    local binariesList=(  );
    local packageName="$1";
    local option="$2"
    #printf "packageName: %sn" "$packageName"

    # set verbosity
    if [[ "-v" == "$2" || "--verbose" == "$2" ]]; then
        beVerbose="true";
    fi

    local isPackageMissing=$(dpkg -L foo 2>&1|grep "package '${packageName}' is not installed"|wc -l);
    if [[ "0" != "${isPackageMissing}" ]]; then
        echo "Package '${packageName}' is not installed.";
        return 0;
    fi

    local allPackageFilesList=($(dpkg -L ${packageName} 2>/dev/null|grep -Pv '^(/.$|/usr/(?:share/)?(?:applications|dbus-d|doc|doc-base|icons|lib|lintian|man|nemo|pixmaps|polkit-d)b(?:/.*)?$|/etcb(?:/.*))'));
    #printf "sizeof(allPackageFilesList): %sn" "${#allPackageFilesList[@]}"

    for packagePath in "${allPackageFilesList[@]}"; do
        #printf "packagePath-raw: %sn" "$packagePath"
        if [[ "" == "${packagePath}" ]]; then
            continue;

        elif [[ -d "${packagePath}" ]]; then
            # skip directories
            continue;
        fi
        # make sure the file is executable
        if [[ ! -x "${packagePath}" ]]; then
            continue;
        fi
        #debug
        #printf "packagePath-executable: %sn" "$packagePath"

        # add to list
        binariesList+=("${packagePath}");
    done

    if [[ "0" == "${binariesList[@]}" ]]; then
        echo "No executable files found for package '${packageName}'";
        echo "This is common for library packages but can occassionally be a sign that a non-library package was not installed correctly and does not have the execute permission set on one or more files.";
        return 503;
    fi

    # trim down path list to only those that have files
    local finalPathsList=(  );
    local initialPathsList=($(echo "$PATH"|sed -E 's/:/n/g'));
    for path in "${initialPathsList[@]}"; do
        if [[ ! -d "${path}" ]]; then
            continue;
        fi
        # remove any trailing slashes
        if [[ "/" == "${path}" ]]; then
            path="${path:0:${#path}-1}";
        fi
        finalPathsList+=("${path}");
    done

    if [[ "true" == "${beVerbose}" ]]; then
        echo "=======================================================";
        echo "List of executable files in package [ ${#binariesList[@]} file(s) ]:";
        echo "=======================================================";
    fi
    local parentDir="";
    local pathAddressableBinariesList=(  );
    for file in "${binariesList[@]}"; do
        #echo "---------------------------------------------";
        if [[ "true" == "${beVerbose}" ]]; then
            echo "${file}";
        fi

        # Check if the current package file is directly addressable
        # on the $PATH (e.g. as opposed to via a symlink on $PATH)
        parentDir=$(dirname "$file");
        for path in "${finalPathsList[@]}"; do
            # if file is directly under current path, add it and move on
            if [[ "${parentDir}" == "${path}" ]]; then
                pathAddressableBinariesList+=("${file}");
                break; # break out of inner loop
            fi
        done
    done

    if [[ "0" != "${#pathAddressableBinariesList[@]}" ]]; then
        if [[ "true" == "${beVerbose}" ]]; then
            echo "";
        fi
        echo "=======================================================";
        echo "PATH-addressable binaries [ ${#pathAddressableBinariesList[@]} file(s) ]:";
        echo "=======================================================";
        for file in "${pathAddressableBinariesList[@]}"; do
            echo "${file}";
        done
    fi
}
function addPPAIfNotInSources () {
    # get sudo prompt out of way up-front so that it
    # doesn't appear in the middle of other output
    sudo ls -acl 2>/dev/null >/dev/null;

    local useLogFile="false";
    local logFile="/dev/null";
    if [[ "" != "${INSTALL_LOG}" ]]; then
        useLogFile="true";
        logFile="${INSTALL_LOG}";
    fi

    local ppaUrl="$1";
    local ppaPath="${ppaUrl:4}";

    if [[ "" == "$ppaUrl" ]]; then
        echo " ERROR: addPPAIfNotInSources(): Found empty PPA URL." | tee -a "${logFile}";
        echo " Aborting function call" | tee -a "${logFile}";
        return;
    fi

    if [[ ! $ppaUrl =~ ^ppa:[A-Za-z0-9][-A-Za-z0-9_.+]*/[A-Za-z0-9][-A-Za-z0-9_.+]*$ ]]; then
        echo " ERROR: addPPAIfNotInSources(): Invalid PPA URL format." | tee -a "${logFile}";
        echo "           Found '${ppaUrl}'" | tee -a "${logFile}";
        echo "           Expected 'ppa:[A-Za-z0-9][-A-Za-z0-9_.+]*/[A-Za-z0-9][-A-Za-z0-9_.+]*'" | tee -a "${logFile}";
        echo " Aborting function call" | tee -a "${logFile}";
        return;
    fi
    #echo "Detected '${ppaUrl}' as valid";

    local existingSourceMatches=$(grep -R "${ppaPath}" /etc/apt/sources.list.d/*.list|wc -l);
    #echo "existingSourceMatches: $existingSourceMatches";
    if [[ "0" != "${existingSourceMatches}" ]]; then
        echo "addPPAIfNotInSources(): Found '${ppaPath}' in existing source(s); skipping..." | tee -a "${logFile}";
        echo " Aborting function call" | tee -a "${logFile}";
        return;
    fi

    #PPA doesn't exist in sources, so add it...
    sudo add-apt-repository -y $* > /dev/null;
}
function addCustomSource() {
    # get sudo prompt out of way up-front so that it
    # doesn't appear in the middle of other output
    sudo ls -acl 2>/dev/null >/dev/null;

    local useLogFile="false";
    local logFile="/dev/null";
    if [[ "" != "${INSTALL_LOG}" ]]; then
        useLogFile="true";
        logFile="${INSTALL_LOG}";
    fi

    local errorMessage="";
    local showUsageInfo="false";
    local hasMissingOrInvalidInfo="false";

    if [[ "-h" == "$1" || "--help" == "$1" ]]; then
        showUsageInfo="true";
    fi

    local repoName="$1";
    local repoDetails="$2";
    if [[ "true" != "$showUsageInfo" ]]; then
        #if not just displaying help info, then check passed args
        if [[ "" == "${repoName}" ]]; then
            hasMissingOrInvalidInfo="true";
            errorMessage="no arguments";

        elif [[ "" == "${repoDetails}" ]]; then
            hasMissingOrInvalidInfo="true";
            errorMessage="missing arguments - must have REPO_NAME and REPO_DETAILS";

        elif [[ "official-package-repositories" == "$repoName" || "additional-repositories" == "$repoName" ]]; then
            hasMissingOrInvalidInfo="true";
            errorMessage="invalid REPO_NAME '${repoName}'; this name is reserved for system usage";

        elif [[ ! $repoName =~ ^[A-Za-z0-9][-A-Za-z0-9.]*[A-Za-z0-9]$ ]]; then
            hasMissingOrInvalidInfo="true";
            errorMessage="invalid REPO_NAME '${repoName}' - only alphanum/hyphen/period allowed, must start/end with alphanum";
        fi

        if [[ 'true' != "${hasMissingOrInvalidInfo}" ]]; then
            echo "Validating repo details";
            #check if more than 2 args
            arg3="$3";
            arg4="$4";
            arg5="$5";
            arg6="$6";
            if [[ 'deb' == "${repoDetails}" ]]; then
                echo "Found repoDetails as multiple arguments; attempting to combine ...";

                if [[ "" == "${arg3}" || "" == "${arg4}" ]]; then
                    hasMissingOrInvalidInfo="true";
                    errorMessage="missing/invalid repo details (only 'deb' but not server/path). Try quoting args after file name?";

                elif [[ ! $arg3 =~ ^https?://[A-Za-z0-9][-A-Za-z0-9.]*.*$ ]]; then
                    hasMissingOrInvalidInfo="true";
                    errorMessage="missing/invalid repo details (repo server) for '${arg3}'. Try quoting args after file name?";

                elif [[ "" != "${arg6}" ]]; then
                    repoDetails="deb $arg3 $arg4 $arg6";

                elif [[ "" != "${arg5}" ]]; then
                    repoDetails="deb $arg3 $arg4 $arg5";

                else
                    repoDetails="deb $arg3 $arg4";
                fi
            fi

            # Check known formats
            architecturelessRepoDetails=$(echo "$repoDetails"|sed 's/^([deb ]*)*[arch=[A-Za-z0-9][-A-Za-z0-9.]*] /1/');
            echo "architecturelessRepoDetails: '${architecturelessRepoDetails}'";
            if [[ $architecturelessRepoDetails =~ ^deb https?://[A-Za-z0-9][-A-Za-z0-9.]*[^ ]* [^ ]* ?[^ ]*$ ]]; then
                echo "OK: repo details appear to be valid.";
                repoDetails="$repoDetails";

            elif [[ $architecturelessRepoDetails =~ ^https?://[A-Za-z0-9][-A-Za-z0-9.*[^ ]* [^ ]* ?[^ ]*$ ]]; then
                echo "OK: repo details appear to be valid but does not start with 'deb'; prepending ...";
                repoDetails="deb $repoDetails";

            else
                hasMissingOrInvalidInfo="true";
                errorMessage="invalid/unsupported repo details format for '${repoDetails}'";
            fi
        fi
    fi

    if [[ "true" == "$showUsageInfo" || "true" == "$hasMissingOrInvalidInfo" ]]; then
        if [[ "true" == "$hasMissingOrInvalidInfo" ]]; then
            echo "ERROR: addCustomSource(): ${errorMessage}." | tee -a "${logFile}";
        fi
        echo "" | tee -a "${logFile}";
        echo "usage:" | tee -a "${logFile}";
        echo "   addCustomSource REPO_NAME REPO_DETAILS" | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        echo "   Adds the specified source under /etc/apt/sources.list.d/" | tee -a "${logFile}";
        echo "   if it does not already exist. Both the repo name and the" | tee -a "${logFile}";
        echo "   details will be considered when checking for existing sources." | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        echo "   REPO_NAME:    user-defined name; only used for the" | tee -a "${logFile}";
        echo "                 naming the apt source list file." | tee -a "${logFile}";
        echo "                 Names must start/end with alphanumeric characters." | tee -a "${logFile}";
        echo "                 Hyphens/periods are allowed for intervening characters." | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        echo "   REPO_DETAILS: Info that goes in the apt source list file." | tee -a "${logFile}";
        echo "                 Generally is in the format of:" | tee -a "${logFile}";
        echo "                 deb REPO_BASE_URL REPO_RELATIVE_PATH" | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        echo "examples:" | tee -a "${logFile}";
        echo "   addCustomSource sublimetext 'deb https://download.sublimetext.com/ apt/stable/' " | tee -a "${logFile}";
        echo "   addCustomSource sublimetext deb https://download.sublimetext.com/ apt/stable/ " | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        return;
    fi

    #check if it already exists...
    echo "Checking if repo source file already exists..." | tee -a "${logFile}";
    if [[ -f "/etc/apt/sources.list.d/${repoName}.list" ]]; then
        echo "addCustomSource(): Source ${repoName} already defined; skipping..." | tee -a "${logFile}";
        return;
    else
        echo "  -> PASSED";
    fi

    #check if details already exist...
    echo "Checking if repo details not already defined in another file ..." | tee -a "${logFile}";
    local existingRepoDetsCount=$(sudo grep -Ri "${repoDetails}" /etc/apt/sources.list.d/*.list 2>/dev/null|wc -l);
    if [[ "0" != "${existingRepoDetsCount}" ]]; then
        echo "addCustomSource(): Repo details already defined for '${repoDetails}'; skipping..." | tee -a "${logFile}";
        echo "Existing matches:" | tee -a "${logFile}";
        echo "" | tee -a "${logFile}";
        sudo grep -RHni "${repoDetails}" /etc/apt/sources.list.d/*.list 2>/dev/null | tee -a "${logFile}";
        return;
    else
        echo "  -> PASSED";
    fi

    # add new source
    echo "Adding source as '${repoName}.list' ..." | tee -a "${logFile}";
    echo "${repoDetails}" | sudo tee "/etc/apt/sources.list.d/${repoName}.list" >/dev/null;

    # safety
    sudo chown root:root /etc/apt/sources.list.d/*.list;
    sudo chmod 644 /etc/apt/sources.list.d/*.list;

}
function listUninstalledPackageRecommends() {
    local packageList="$1";
    local hasRecommends=$(sudo apt install --assume-no "${packageList}" 2>/dev/null|grep 'Recommended packages:'|wc -l);
    if [[ "0" == "${hasRecommends}" ]]; then
        echo "";
        return;
    fi
    # note the first sed is to remove a pipe that was present in
    # actual output from apt install; see 'sudo apt install --assume-no ledgersmb'
    sudo apt install --assume-no "${packageList}" 2>/dev/null|sed -E 's/(s+)|s+/1/g'|sed '/^The following NEW packages will be installed:$/Q'|sed '0,/^Recommended packages:$/d'|sed -E 's/^s+|s+$//g'|tr ' ' 'n';
}
function listUninstalledPackageSuggests() {
    local packageList="$1";
    local hasSuggests=$(sudo apt install --assume-no "${packageList}" 2>/dev/null|grep 'Suggested packages:'|wc -l);
    if [[ "0" == "${hasSuggests}" ]]; then
        echo "";
        return;
    fi
    # note the first sed is to remove a pipe that was present in
    # actual output from apt install; see 'sudo apt install --assume-no ledgersmb'
    sudo apt install --assume-no "${packageList}" 2>/dev/null|sed -E 's/(s+)|s+/1/g'|sed '/^The following NEW packages will be installed:$/Q'|sed '/^Recommended packages:$/Q'|sed '0,/^Suggested packages:$/d'|sed -E 's/^s+|s+$//g'|tr ' ' 'n';
}
function previewUpgradablePackagesDownloadSize() {
   #get sudo prompt out of the way so it doesn't appear in the middle of output
    sudo ls -acl >/dev/null;

    echo "";
    echo "=============================================================";
    echo "Updating apt cache ...";
    echo "=============================================================";
    sudo apt update 2>&1|grep -Pv '^(Build|Fetch|Get|Hit|Ign|Read|WARNING|$)'|sed -E 's/^(.*) Run.*$/-> 1/g';
    echo "-> Getting list of upgradable packages ...";

    local upgradablePackageList=$(sudo apt list --upgradable 2>&1|grep -Pv '^(Listing|WARNING|$)'|sed -E 's/^([^/]+)/.*$/1/g'|tr 'n' ' '|sed -E 's/^s+|s+$//g');
    local upgradablePackageArray=($(echo "$upgradablePackageList"|tr ' ' 'n'));
    #echo "upgradablePackageArray size: ${#upgradablePackageArray[@]}"

    echo "";
    echo "=============================================================";
    echo "Calculating download sizes (note: there may be overlaps) ...";
    echo "=============================================================";

    echo "";
    newPackageCount=0;
    for packageName in "${upgradablePackageArray[@]}"; do
        #echo "packageName: '$packageName'"
        apt show "$packageName" 2>/dev/null|grep --color=never -P '(Package|Version|Installed-Size|Download-Size):';
        is_installed=$(apt install --simulate --assume-yes "$packageName" 2>/dev/null|grep --color=never 'already the newest');
        if [[ "" == "${is_installed}" ]]; then
            newPackageCount=$(( newPackageCount + 1 ));
            aptitude install --simulate --assume-yes --without-recommends "$packageName" 2>/dev/null|grep 'Need to get'|tail -1|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With dependencies only:           1 2/g'
            aptitude install --simulate --assume-yes --with-recommends    "$packageName" 2>/dev/null|grep 'Need to get'|tail -1|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With dependencies and recommends: 1 2/g'
        else
            echo "${is_installed}";
        fi
        echo "";
    done
    echo "";
    echo "=============================================================";
    echo "Total:";
    echo "=============================================================";
    #echo "test: ${upgradablePackageArray[@]}"
    aptitude install --simulate --assume-yes --without-recommends "${upgradablePackageArray[@]}" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With dependencies only:           1 2/g'
    aptitude install --simulate --assume-yes --with-recommends    "${upgradablePackageArray[@]}" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With dependencies and recommends: 1 2/g'
    echo "";
}
function previewPackageDownloadSize() {
    if [[ "0" == "${#@}" ]]; then
        echo "Expected usage:";
        echo "previewPackageDownloadSize PACKAGE_NAME";
        echo "previewPackageDownloadSize PACKAGE1 [PACKAGE2 [PACKAGE3 [...]]]] ";
        return;
    fi
   #get sudo prompt out of the way so it doesn't appear in the middle of output
    sudo ls -acl >/dev/null;

    echo "=============================================================";
    newPackageCount=0;
    for packageName in "$@"; do
        apt show "$packageName" 2>/dev/null|grep --color=never -P '(Package|Version|Installed-Size|Download-Size):';
        is_installed=$(apt install --simulate --assume-yes "$packageName" 2>/dev/null|grep --color=never 'already the newest');
        if [[ "" == "${is_installed}" ]]; then
            newPackageCount=$(( newPackageCount + 1 ));
            aptitude install --simulate --assume-yes --without-recommends "$packageName" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/Without recommends: 1 2/g'
            aptitude install --simulate --assume-yes --with-recommends "$packageName" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With recommends:    1 2/g'
        else
            echo "${is_installed}";
        fi
        echo "=============================================================";
    done
    if [[ "0" != "${newPackageCount}" ]]; then
        echo "Total:"
        aptitude install --simulate --assume-yes --without-recommends "${@}" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/Without recommends: 1 2/g'
        aptitude install --simulate --assume-yes --with-recommends "${@}" 2>/dev/null|grep 'Need to get'|sed -E 's/^Need to get ([0-9[[0-9.,]*) ([kmgKMG]i?[Bb]).*$/With recommends:    1 2/g'
    fi
}
function installPackages() {
    # get sudo password prompt out of the way early on (for cleaner message display)
    sudo ls -acl 2>&1 >/dev/null

    local installOptions="-y -qq -o=Dpkg::Use-Pty=0";
    local packageList="$1";
    local installRecommends="$2";
    local installSuggests="$3";
    local showProgress="$4";

    if [[ "true" == "${installRecommends}" ]]; then
        installOptions="${installOptions} --install-recommends";
    fi
    if [[ "true" == "${installSuggests}" ]]; then
        installOptions="${installOptions} --install-suggests";
    fi
    if [[ "true" == "${showProgress}" ]]; then
        installOptions="${installOptions} --show-progress";
    fi

    if [[ "" == "$INSTALL_LOG" ]]; then
        sudo apt install ${installOptions} ${packageList} 2>&1 | grep -v 'apt does not have a stable CLI interface';
        return;
    fi
    echo -e "nRunning: sudo apt install ${installOptions} ${packageList} | grep -v 'apt does not have a stable CLI interface'" | tee -a "${INSTALL_LOG}";
    sudo apt install ${installOptions} ${packageList} 2>&1 | grep -v 'apt does not have a stable CLI interface' | tee -a "${INSTALL_LOG}";
}
function installPackagesWithRecommends() {
    installPackages "$1" "true" "false" "$2";
}
function installPackagesWithRecommendsAndSuggests() {
    installPackages "$1" "true" "true" "$2";
}
function verifyAndInstallPackagesFromMap() {
    #================================================================
    # This function will verify all of the passed packages are
    # installed. If any are not installed, it will attempt to
    # install them. If all packages are verified as installed, it
    # will return 0 to indicate success. Otherwise, it will return
    # a non-zero value to indicate failure.
    #================================================================

    # get sudo prompt out of way up-front so that it
    # doesn't appear in the middle of other output
    sudo ls -acl 2>/dev/null >/dev/null;

    # ==================================================================
    # This function expects $1 to be an associative array (aka a map)
    # which contains:
    #   Map<Key=localBinaryPath,Value=packageNameOfBinary>
    # where
    # localBinaryPath     = path to a local binary (e.g. /usr/bin/7z)
    # packageNameOfBinary = install package for binary (e.g. p7zip-full)
    # ==================================================================
    # Sample usage:
    #
    # # 1) Define a dependenciesMap
    # declare -A dependenciesMap=(
    #   ['/usr/bin/7z']='p7zip-full'
    #   ['/usr/bin/curl']='curl'
    #   ['/usr/bin/yad']='yad'
    #   ['/usr/bin/convert']='imagemagick'
    # );
    #
    # # 2) pass map to function
    # verifyAndInstallPackagesFromMap "$(declare -p dependenciesMap)";
    #
    # # 3) check function return code (0 is pass; non-zero is fail)
    # if [[ "0" == "$?" ]]; then echo "pass"; else echo "fail"; fi
    # ==================================================================
    if [[ "" == "$1" ]]; then
        return 501;
    fi

    local binPathKey="";
    local packageNameValue="";
    local binExists="";
    local status=0;

    eval "declare -A dependenciesMap="${1#*=}
    for i in "${!dependenciesMap[@]}"; do
        binPathKey="$i";
        reqPkgName="${dependenciesMap[$binPathKey]}";
        #echo "-----------"
        #printf "%st%sn" "$binPathKey ==> ${reqPkgName}"

        #check if binary path exists
        binExists=$(/usr/bin/which "${binPathKey}" 2>/dev/null|wc -l);
        #printf "%st%st:t%sn" "$binPathKey ==> ${reqPkgName}" "$binExists"
        if [[ "1" == "${binExists}" ]]; then
            # if it exists, then we can skip that dependency
            continue;

        elif [[ "0" == "${binExists}" ]]; then
            # attempt to install missing package
            sudo apt-get install -y "${reqPkgName}" 2>&1 >/dev/null;
            if [[ "$?" != "0" ]]; then
                status=503;
                continue;
            fi
            binExists=$(/usr/bin/which "${binPathKey}" 2>/dev/null|wc -l);
            if [[ "1" != "${binExists}" ]]; then
                status=504;
                continue;
            fi
        else
            # any other possibility means multiple matches were
            # returned from /usr/bin/which; which should not be possible
            status=505;
            continue;
        fi
        printf "%st%sn" "$binPathKey ==> ${reqPkgName}";
    done
    return ${status};
}
function verifyAndInstallPackagesFromList() {
    #================================================================
    # This function will verify all of the passed packages are
    # installed. If any are not installed, it will attempt to
    # install them. If all packages are verified as installed, it
    # will return 0 to indicate success. Otherwise, it will return
    # a non-zero value to indicate failure.
    #================================================================

    # get sudo prompt out of way up-front so that it
    # doesn't appear in the middle of other output
    sudo ls -acl 2>/dev/null >/dev/null;

    # This function should not be called if there are no
    # required packages; instead assume this is an error
    if [[ "" == "$1" ]]; then
        return 501;
    fi

    # if checks are disabled, then abort without error
    local skipFlagName="--no-verify-depends";
    local option="$2";
    if [[ "${option}" == "${skipFlagName}" ]]; then
        return 0;
    fi

    local quietFlagName="--quiet";
    local requiredPackagesList="$1";
    local status=0;
    for reqPkgName in $(echo "${requiredPackagesList}"); do
        pkgStatus=$(apt search "${reqPkgName}"|grep -P "^i\w*\s+\b${reqPkgName}\b"|wc -l);
        if [[ "1" == "${pkgStatus}" ]]; then
            # package already installed; skip to next one
            continue;
        elif [[ "0" != "${pkgStatus}" ]]; then
            if [[ "${option}" != "${quietFlagName}" ]]; then
                echo "ERROR: package '${reqPkgName}' cannot be verified due to multiple matches.";
                echo "Script needs to be updated or used with the ${skipFlagName} option.";
            fi
            status=502;
            continue;
        else
            sudo apt-get install -y "${reqPkgName}" 2>&1 >/dev/null;
            if [[ "$?" != "0" ]]; then
                status=503;
                continue;
            fi
            pkgStatus=$(apt search "${reqPkgName}"|grep -P "^i\w*\s+\b${reqPkgName}\b"|wc -l);
            if [[ "1" != "${pkgStatus}" ]]; then
                status=504;
                continue;
            fi
        fi
    done
    return ${status};
}
function list_installed_ppa_repos() {
    echo "===================================================";
    echo "Launchpad PPAs:";
    echo "===================================================";
    grep -PRh '^debs+https?://ppa.launchpad.net' /etc/apt/sources.list.d/*.list|awk -F' ' '{print $2}'|awk -F/ '{print "sudo apt-add-repository ppa:"$4"/"$5}'|sort -u;
    echo "";
    echo "===================================================";
    echo "Custom PPAs:";
    echo "===================================================";
    grep -PR '^debs+' /etc/apt/sources.list.d/*.list --exclude=official* --exclude=additional*|grep -v 'ppa.launchpad.net'|sort -u|sed -E "s/^(\/etc\/apt\/sources.list.d\/[^:]+.list):(.*)$/echo "2"|sudo tee "1"/";
}
#==========================================================================
# End Section: Package Management functions
#==========================================================================

#==========================================================================
# Start Section: Process functions
#==========================================================================
function getProcessInfoByInteractiveMouseClick() {
    ps -o pid,comm,start,etime,pcpu,pmem,size,args -p $(echo $(PIDSTR=$(xprop _NET_WM_PID); echo "$PIDSTR" | sed "s/^.*[^0-9]([0-9][0-9]*)[^0-9]*$/1/g"))
}
function getProcessIdByWindowName() {
    local TARGET_NAME="$1";
    xdotool search --class "$TARGET_NAME" getwindowpid
}
function getProcessInfoByWindowName() {
    local TARGET_NAME="$1";
    ps -o pid,comm,start,etime,pcpu,pmem,size,args -p $(xdotool search --class "$TARGET_NAME" getwindowpid);
}
function printAtQueue() {
    declare -A jobSchedulesMap;

    local MINJOB=$(/usr/bin/atq | sort | head -n1 | awk '{ print $1; }');
    local MAXJOB=$(/usr/bin/atq | sort | tail -n1 | awk '{ print $1; }');
    if [[ "" != "${MINJOB}" && "" != "${MAXJOB}" && $MINJOB =~ ^[0-9]+$ && $MAXJOB =~ ^[0-9]+$ ]]; then
        ## put job list into a Map, then find paths, then use printf to display both data points together
        eval $(/usr/bin/atq|gawk -F'\s+' '{print $1" ""$0"""}'|xargs -n 2 sh -c 'echo "jobSchedulesMap["$1"]="$2""' argv0);

        # print a header
        printf '%-7s %-10s %s %-6s %-20s %sn' 'JOBID' 'DATE' 'TIME     YEAR' 'QUEUE' 'USER' 'COMMAND';
        printf '==================================================================================================================n';

        local jobId='';
        for jobId in $(seq ${MINJOB} ${MAXJOB}); do
            # the command to be run is always in the 2nd to last line returned by $(at -c ID)
            # and last line is blank
            #
            local commandToBeRun=$(at -c ${jobId}|grep -Pv '^$'|tail -1);
            local scheduleInfo="${jobSchedulesMap[$jobId]}";

            local scheduledDate=$(echo "${scheduleInfo}" | sed -E 's/^[1-9][0-9]*s+(.*)s+[0-9]{2}:[0-9]{2}:[0-9]{2}s+[1-9][0-9]{3}.*$/1/g');
            local scheduledTimeAndYear=$(echo "${scheduleInfo}" | sed -E 's/^.*s+([0-9]{2}:[0-9]{2}:[0-9]{2}s+[1-9][0-9]{3})s+.*$/1/g');
            local queueName=$(echo "${scheduleInfo}" | sed -E 's/^.*:[0-9]{2}s+[1-9][0-9]{3}s+(S+)s+.*$/1/g');
            local jobUser=$(echo "${scheduleInfo}" | sed -E 's/^.*:[0-9]{2}s+[1-9][0-9]{3}s+S+s+(S+)$/1/g');

            # Print consolidated row as output
            printf '%-7s %-10s %s %-6s %-20s %sn' "${jobId}" "${scheduledDate}" "${scheduledTimeAndYear}" "${queueName}" "${jobUser}" "${commandToBeRun}";
        done
    fi
    unset jobSchedulesMap;
}
function rescheduleAtJob() {
    local jobId="$1";
    if [[ "" == "$1" || ! $jobId =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: rescheduleAtJob(): Invalid jobId '${jobId}'; aborting...";
        return -1;
    fi

    local newTime="$2";
    if [[ "" == "$2" || ! $newTime =~ ^[0-9][0-9]:[0-9][0-9].*$ ]]; then
        echo "ERROR: rescheduleAtJob(): Invalid newTime '${newTime}'.";
        echo "newTime must begin with %H:%M (e.g. 02:00). This can be in 24-hr format or 12-hr format with am/pm (e.g. 02:00am)";
        echo "newTime may also include a date or keywords such as 'today'/'tomorrow' after the time (e.g. '02:00am tomorrow')";
        echo "For more info, see 'man at'";
        echo "";
        return -2;
    fi

    local jobExists=$(/usr/bin/atq|grep -Pc "^${jobId}\b");
    if [[ "1" != "${jobExists}" ]]; then
        echo "ERROR: rescheduleAtJob(): No AT jobs with jobId '${jobId}'; aborting...";
        return -3;
    fi

    at -c ${jobId}|grep -Pv '^$'|tail -1|at ${newTime};
    atrm ${jobId};
}
function addMinutesToAtJob() {
    local jobId="$1";
    if [[ "" == "$1" || ! $jobId =~ ^[1-9][0-9]*$ ]]; then
        echo "ERROR: addMinutesToAtJob(): Invalid jobId '${jobId}'; aborting...";
        return -1;
    fi

    local minutesToAdd="$2";
    if [[ "" == "$2" || ! $minutesToAdd =~ ^[-+][1-9][0-9]*$ ]]; then
        echo "ERROR: addMinutesToAtJob(): Invalid minutesToAdd '${minutesToAdd}'; expected a plus sign followed by a number of minutes, e.g. '+30'. Aborting...";
        return -2;
    fi

    local jobExists=$(/usr/bin/atq|grep -Pc "^${jobId}\b");
    if [[ "1" != "${jobExists}" ]]; then
        echo "ERROR: addMinutesToAtJob(): No AT jobs with jobId '${jobId}'; aborting...";
        return -3;
    fi
    local currentScheduleDate=$(/usr/bin/atq|grep -P "^${jobId}\s+"|sed -E 's/[1-9][0-9]*s+(Mon|T[hu][eu]|Wed|Fri|S[au][nt])s+(J[au][nl]|Feb|Ma[ry]|A[up][rg]|Sep|Oct|Nov|Dec)s+([0-3]?[0-9])s+([0-2][0-9]:[0-5][0-9]):.*$/2 3/g');
    local currentSchedule24HourTime=$(/usr/bin/atq|grep -P "^${jobId}\s+"|sed -E 's/[1-9][0-9]*s+(Mon|T[hu][eu]|Wed|Fri|S[au][nt])s+(J[au][nl]|Feb|Ma[ry]|A[up][rg]|Sep|Oct|Nov|Dec)s+[0-3]?[0-9]s+([0-2][0-9]:[0-5][0-9]):.*$/3/g');
    local todaysDate=$(date --date 'today' +'%b %d');
    local tomorrowsDate=$(date --date 'tomorrow' +'%b %d');

    local newTime="";
    if [[ "$currentScheduleDate" == "${todaysDate}" ]]; then
        newTime=$(date --date "${currentSchedule24HourTime} today ${minutesToAdd} minute" +'%I:%M%p %b %d');
    elif [[ "$currentScheduleDate" == "${tomorrowsDate}" ]]; then
        newTime=$(date --date "${currentSchedule24HourTime} tomorrow ${minutesToAdd} minute" +'%I:%M%p %b %d');
    else
        newTime=$(date --date "${currentSchedule24HourTime} ${currentScheduleDate} ${minutesToAdd} minute" +'%I:%M%p %b %d');
    fi

    at -c ${jobId}|grep -Pv '^$'|tail -1|at ${newTime};
    atrm ${jobId};
}
#==========================================================================
# End Section: Process functions
#==========================================================================

#==========================================================================
# Start Section: Hardware functions
#==========================================================================
function printBatteryPercentages() {
    # this assumes that you only have 1 wireless device

    # 1. Get info from upower; this won't have everything (missing xbox 360 wireless)
    #       but it should have wireless kb/m and possibly some wireless controllers
    #
    #   1.1. get the dump from upower
    #   1.2. remove any info blocks for 'daemon'; they don't have any worthwhile info anyway
    #           perl -0 -pe 's/(?:^|nn)Daemon:.*?nn/n/gsm'
    #   1.3. remove any device attribute lines not related to either model or (battery) percentage
    #        while simultaneously reformatting
    #           perl -ne 'if ( /^$/ ) { print "n" } elsif ( /^.*model:[ t]+(.*)$/ ) { print "$1: " } elsif ( /^.*percentage:[ t]+(.*)$/ ) { print "$1" }'

    upower --dump | perl -0 -pe 's/(?:^|nn)Daemon:.*?nn/n/gsm' | perl -ne 'if ( /^$/ ) { print "n" } elsif ( /^.*model:[ t]+(.*)$/ ) { print "$1: " } elsif ( /^.*percentage:[ t]+(.*)$/ ) { print "$1" }' | sed '/^$/d';
}
function unmuteAllAlsaAudioControls() {
    local INITIAL_IFS="$IFS";
    IFS='';
    amixer scontrols | sed "s|[^']*('[^']*').*|1|g" |
    while read control_name
    do
        if [[ "'Auto-Mute Mode'" ==  "$control_name" || "'Input Source'" ==  "$control_name" ]]; then
            #Skip these ones -- not really valid sources
            continue;
        fi
        #echo "control name: $control_name";
        amixer -q set "$control_name" 100% unmute;
        if [[ "0" != "$?" ]]; then
            echo "Error unmuting control name: $control_name";
        fi
    done
    IFS="$INITIAL_IFS";
}
#==========================================================================
# End Section: Hardware functions
#==========================================================================

#==========================================================================
# Start Section: Service functions
#==========================================================================
function stopSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl stop $passedarg
    done
}
function disableSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl disable $passedarg
    done
}
function stopAndDisableSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl stop $passedarg
        sudo systemctl disable $passedarg
    done
}
function enableSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl enable $passedarg
    done
}
function restartSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl restart $passedarg
    done
}
function enableAndRestartSystemdServices() {
    for passedarg in "$@"; do
        #echo "passedarg is $passedarg"
        sudo systemctl enable $passedarg
        sudo systemctl restart $passedarg
    done
}
#==========================================================================
# End Section: Service functions
#==========================================================================

#==========================================================================
# Start Section: Launcher functions
#==========================================================================
function openGitExtensionsBrowse() {
    #launch background process
    (cd "$1"; /usr/bin/gitext >/dev/null 2>/dev/null;)&
}
function openFileInTextEditor() {
    openFileInSublime "$1";
}
function openFileInSublime() {
    #launch background process
    (/usr/bin/sublime "$1" >/dev/null 2>/dev/null;)&
}
function openFileInXed() {
    #launch background process
    (/usr/bin/xed "$1" >/dev/null 2>/dev/null;)&
}
function mergeFilesInMeld() {
    #launch background process
    (/usr/bin/meld "$1" "$2" >/dev/null 2>/dev/null;)&
}
function openNemo() {
    #launch background process
    (/usr/bin/nemo "$1" >/dev/null 2>/dev/null)&
}
#==========================================================================
# End Section: Launcher functions
#==========================================================================

#==========================================================================
# Start Section: Reference functions
#==========================================================================
# colorize man pages. See: https://www.ryanschulze.net/archives/2113
function man() {
  LESS_TERMCAP_mb=$(tput setaf 4)  LESS_TERMCAP_md=$(tput setaf 4;tput bold)   LESS_TERMCAP_so=$(tput setaf 7;tput setab 4;tput bold)   LESS_TERMCAP_us=$(tput setaf 6)   LESS_TERMCAP_me=$(tput sgr0)   LESS_TERMCAP_se=$(tput sgr0)   LESS_TERMCAP_ue=$(tput sgr0)   command man "$@"
}
function referenceGroupCommands() {
    # -------------------------------------------------------------------------------------------------
    # References:
    # https://www.howtogeek.com/50787/add-a-user-to-a-group-or-second-group-on-linux/
    # man find
    # 2>&- usage:
    #   https://unix.stackexchange.com/a/19433, https://stackoverflow.com/a/20564208, https://unix.stackexchange.com/a/131833
    # -------------------------------------------------------------------------------------------------

    echo "Group Administration Commands:";
    echo "======================================================================================================";
    echo " sudo groupadd GROUP                     # create new group 'GROUP' ";
    echo " sudo groupadd -g 1337 GROUP             # create new group 'GROUP' with groupid (gid) as 1337 ";
    echo "";
    echo "# adds existing user 'USER' to existing group 'GROUP'";
    echo " sudo usermod -a -G GROUP USER";
    echo " sudo gpasswd -a USER GROUP";
    echo " sudo gpasswd --add USER GROUP";
    echo "";
    echo "# adds existing user 'USER' to a list of muliple groups 'GROUP1' and 'GROUP2'";
    echo " sudo usermod -a -G GROUP1,GROUP2 USER";
    echo "";
    echo "# removes existing user 'USER' from existing group 'GROUP'";
    echo " sudo gpasswd -d USER GROUP";
    echo " sudo gpasswd --delete USER GROUP";
    echo "";
    echo "# remove the user 'USER' from any groups not explicitly listed";
    echo " sudo usermod -G USER USER         # User 'USER' will belong to *only* the default group 'USER' ";
    echo " sudo usermod -G USER,GROUP2 USER  # User will belong to *only* to groups 'USER' and 'GROUP2' ";
    echo "";
    echo " sudo usermod -g GROUP USER              # change the primary group of user 'USER' to group 'GROUP'";
    echo " sudo useradd -G GROUP USER              # create new user 'USER' and adds to existing group 'GROUP'";
    echo " sudo groupdel GROUP                     # delete group 'GROUP'";
    echo " sudo groupmod -n NEWGROUP OLDGROUP      # rename group 'OLDGROUP' to 'NEWGROUP'";
    echo "";
    echo " groups                                  # list the groups current user account is assigned to";
    echo " groups USER                             # list the groups user 'USER' is assigned to";
    echo " members GROUP                           # list the members of group 'GROUP'";
    echo " getent group                            # list all groups on system";
    echo " getent group GROUP                      # list details for group 'GROUP'";
    echo " getent group {1000..60000}              # list all groups on system with gids between 1000 and 60000";
    echo " cat /etc/group                          # manually query group file (don't modify as this could corrupt system)";
    echo " sudo chgrp [-R] GROUP FILE              # change group ownership to GROUP for file FILE";
    echo " find . ! -perm /g=w 2>/dev/null         # find files that the owner can't write to";
    echo " find . ! -perm /g=w 2>&-                # find files that the owner can't write to (alternate)";
    echo " find . ! -group GROUP 2>/dev/null              # find files not owned by group 'GROUP'";
    echo " find . ! -group GROUP 2>&-                     # find files not owned by group 'GROUP' (alternate)";
    echo " find . -group GROUP ! -perm /g=w 2>/dev/null   # find unwritable files owned by group 'GROUP'";
    echo " find . -group GROUP ! -perm /g=w 2>&-          # find unwritable files owned by group 'GROUP' (alternate)";
    echo "";
    echo "# Useful aliases:";
    echo "  groupsref | groupsdoc                  # this help text";
    echo "  lsgroups                               # display non-service groups and their members";
    echo "  lsallgroups                            # display all groups and their members (sorted by id)";
    echo "  lsallgroupsbyname                      # display all groups and their members (sorted by name)";
    echo "";
}
function referenceUserCommands() {
    # -------------------------------------------------------------------------------------------------
    # References:
    # https://www.howtogeek.com/50787/add-a-user-to-a-group-or-second-group-on-linux/
    # man useradd
    # man usermod
    # man find
    # 2>&- usage:
    #   https://unix.stackexchange.com/a/19433, https://stackoverflow.com/a/20564208, https://unix.stackexchange.com/a/131833
    # -------------------------------------------------------------------------------------------------

    echo "User Administration Commands:";
    echo "=========================================================================================================";
    echo "# Create new user 'USER' with LAN access but no local login (reqs running passwd before login):";
    echo "  sudo adduser --gecos "" --no-create-home --disabled-login --shell /bin/false USER";
    echo "";
    echo "# Create new user 'USER' (w home dir, login enabled, reqs running passwd before login):";
    echo "  sudo useradd -m [-g GROUP] [-s SHELL] USER";
    echo "  sudo useradd --create-home [-gid GROUP] [--shell SHELL] USER";
    echo "  sudo usermod [-g GROUP] [-s SHELL] USER";
    echo "";
    echo "# Create new user with default password (only use for initial pwd as this is viewable in .bash_history):";
    echo "  sudo useradd -m [-g GROUP] [-s SHELL] -p PASSWD_HASH USER";
    echo "  sudo useradd --create-home [-gid GROUP] [--shell SHELL] -password PASSWD_HASH USER";
    echo "  sudo usermod [-g GROUP] [-s SHELL] -p PASSWD_HASH USER";
    echo "    ex: sudo useradd -m -p $(echo 'abcd1234'|mkpasswd -m sha-512 -S saltsalt -s) USER";
    echo "";
    echo "# Create new user 'USER' (no home dir, login disabled, reqs running passwd before login):";
    echo "  sudo useradd [-g GROUP]  [-s SHELL] USER";
    echo "  sudo useradd -f 0 -M [-g GROUP]  [-s SHELL] USER";
    echo "  sudo useradd --no-create-home --inactive 0 [--gid GROUP] [--shell SHELL] USER";
    echo "  sudo usermod -L [-g GROUP] [-s SHELL] USER";
    echo "  sudo usermod --lock [--gid GROUP] [--shell SHELL] USER";
    echo "";
    echo "# Move home directory of user 'USER' to NEWHOME:";
    echo "  sudo usermod -m -d NEWHOME -m USER";
    echo "  sudo usermod --move-home --home NEWHOME -m USER";
    echo "";
    echo "# Rename user 'OLDUSER' to 'NEWUSER' (no change to homedir, no change to groupname/group ownership):";
    echo "  sudo usermod -l NEWUSER OLDUSER";
    echo "  sudo usermod --login NEWUSER OLDUSER";
    echo "";
    echo "# Rename user 'OLDUSER' to 'NEWUSER' AND move homedir to NEWHOME (no change to groupname/group ownership):";
    echo "  sudo usermod -m -d NEWHOME -l NEWUSER OLDUSER";
    echo "  sudo usermod --move-home --home NEWHOME --login NEWUSER OLDUSER";
    echo "";
    echo "# Delete user 'USER' (but leave their home dir):";
    echo "  sudo userdel USER";
    echo "";
    echo "# Delete user 'USER' (and remove their home dir):";
    echo "  sudo userdel -r USER";
    echo "";
    echo " id                                      # get id of current user";
    echo " id USER                                 # get id of user 'USER'";
    echo " whoami                                  # display name of current user";
    echo " who --all                               # display logged in users (includes ssh but not terminals spawned by current user)";
    echo " finger USER                             # display basic information about user 'USER'";
    echo " ssh USER@localhost                      # login to user 'USER' on local machine";
    echo " ssh USER@127.0.0.1                      # login to user 'USER' on local machine";
    echo " su - USER                               # switch to user 'USER' from terminal (reboot req'd for new users)";
    echo " exit                                    # return to initial terminal (after successfully using either of the previous 3 commands)";
    echo " su - USER -c COMMAND [args]             # run command as user 'USER'";
    echo " passwd                                  # change password for the current user";
    echo " sudo passwd USER                        # change password for user 'USER'";
    echo " sudo passwd --expire USER               # force user 'USER' to change their password next time they log in";
    echo " groups                                  # list the groups current user account is assigned to";
    echo " groups USER                             # list the groups user 'USER' is assigned to";
    echo " getent passwd                           # list all users on system (including service accounts)";
    echo " getent passwd USER                      # list details for user 'USER'";
    echo " getent passwd {1000..60000}             # list all users on system with uids between 1000 and 60000";
    echo " cat /etc/passwd                         # manually query user file (don't modify as this could corrupt system)";
    echo " sudo chown [-R] USER:GROUP FILE         # change ownership to USER:GROUP for file FILE";
    echo " sudo chown [-R] USER FILE               # change ownership to USER for file FILE";
    echo " find . ! -perm /u=w 2>/dev/null         # find files that the owner can't write to";
    echo " find . ! -perm /u=w 2>&-                # find files that the owner can't write to (alternate)";
    echo " find . ! -user USER 2>/dev/null              # find files not owned by user 'USER'";
    echo " find . ! -user USER 2>&-                     # find files not owned by user 'USER' (alternate)";
    echo " find . -user USER ! -perm /u=w 2>/dev/null   # find unwritable files owned by user 'USER'";
    echo " find . -user USER ! -perm /u=w 2>&-          # find unwritable files owned by user 'USER' (alternate)";
    echo " wall MESSAGE_TEXT                       # broadcast message to all remotely loggged in users (e.g. ssh users)";
    echo " wall -g GROUP MESSAGE_TEXT              # broadcast message to remotely loggged in users in group 'GROUP'";
    echo " sudo pgrep -a -u USER                   # list all processes run by user 'USER'";
    echo " sudo pkill -9 -u USER                   # kill all processes run by user 'USER' (also kicks user login)";
    echo " sudo killall -9 -u USER                 # kill all processes run by user 'USER' (alternate; also kicks user login)";
    echo " sudo chsh -s /bin/false USER            # disable future logins by user 'USER'"
    echo " sudo chsh -s /usr/sbin/nologin USER     # disable future logins by user 'USER' (alternate)"
    echo "";
    echo "# Useful aliases:";
    echo "  usersref | usersdoc                    # this help text";
    echo "  lsusers                                # display non-service account users, their home dirs, and their shells";
    echo "  lsallusers                             # display all users, their home dirs, and their shells (sorted by id)";
    echo "  lsallusersbyname                       # display all users, their home dirs, and their shells (sorted by name)";
    echo "";
}
function referencePermissions() {
    echo "Permission Administration Commands:";
    echo "=======================================";
    echo "# Ownership";
    echo " sudo chown [-R] USER:GROUP FILE         # change ownership to USER:GROUP for file FILE";
    echo " sudo chown [-R] USER FILE               # change ownership to USER for file FILE";
    echo " sudo chgrp [-R] GROUP FILE              # change group ownership to GROUP for file FILE";
    echo "";
    echo "# Access Controls";
    echo " sudo chown [-R] OCTAL_PERMS FILE        # change permissions for file FILE";
    echo " sudo chown [-R] PERM_ABBREV FILE        # change permissions for file FILE";
    echo "";
    echo "# Octal Permission Legend";
    echo "  Octal perms can be given as 3- or 4-digit numbers. When given as 4 digit numbers, ";
    echo "  focus on the 3 right-most positions for the typical access control permissions.";
    echo "";
    echo "  The values in each position are considered separately rather than as a whole.";
    echo "  So 777 is not seven hundred seventy seven but rather 7-7-7.";
    echo "  Each of those numbers represents the permissions for a set of users:"
    echo "    U-- => the 3rd digit from the right (U) = user permissions (for the user owning the file)";
    echo "    -G- => the 2nd digit from the right (G) = group permissions (for the group owning the file)";
    echo "    --O => the 1st digit from the right (O) = other user permissions";
    echo "";
    echo "  The individual values for any set of users can range from 0 (no perms) to 7 (full perms)";
    echo "  Just start with 0 and add the numerical values of whatever permissions you want. The values";
    echo "  of the various permissions are as follows:";
    echo "    0 == No Permissions";
    echo "    1 == Execute permission (needed by all folders; needed to run programs; not needed for regular files)";
    echo "    2 == Write permission (needed to write, delete, or modify a file)";
    echo "    4 == Read permission (needed to read, view, or access a file)";
    echo "  so:";
    echo "    Read (4) + Nothing (0)             == 4";
    echo "    Read (4) + Execute (1)             == 5";
    echo "    Read (4) + Write (2)               == 6";
    echo "    Read (4) + Write (2) + Execute (1) == 7";
    echo ""
    echo "  some examples with the full Octal code can be read as:";
    echo "    777 = User can Read+Write+Execute (7), Group can Read+Write+Execute (7), Others can Read+Write+Execute (7)";
    echo "    755 = User can Read+Write+Execute (7), Group can Read+Execute (5), Others can Read+Execute (5)";
    echo "    766 = User can Read+Write+Execute (7), Group can Read+Write (6), Others can Read+Write (6)";
    echo "    640 = User can Read+Write (0), Group can Read (4), Others have no perms (0)";
    echo "";
    echo "# Octal Permission Examples";
    echo "  chmod 000 FILE => ---------- FILE ";
    echo "  chmod 100 FILE => ---x------ FILE ";
    echo "  chmod 200 FILE => --w------- FILE ";
    echo "  chmod 300 FILE => --wx------ FILE ";
    echo "  chmod 400 FILE => -r-------- FILE ";
    echo "  chmod 500 FILE => -r-x------ FILE ";
    echo "  chmod 600 FILE => -rw------- FILE ";
    echo "  chmod 700 FILE => -rwx------ FILE ";
    echo "  chmod 770 FILE => -rwxrwx--- FILE ";
    echo "  chmod 777 FILE => -rwxrwxrwx FILE ";
    echo "";
    echo "";
    echo "# Permission Abbreviations Legend";
    echo "  Alternately, you can skip Octal and just use abbreviations such as u=r. When doing so,";
    echo "  you'll specify 2 sets of letters: the letters on the left indicate which set of users";
    echo "  the permission applies to and the letters on the right indicate the actual perms.";
    echo "  There are also some special flags that can be set this way that yu cannot set with Octal codes";
    echo "";
    echo "  target letters (left side) - these are case-sensitive:";
    echo "    u: user";
    echo "    g: group";
    echo "    o: other";
    echo "    a: all (same as user + group + owner)";
    echo "";
    echo "  access letters (right side) - these are case-sensitive:";
    echo "    r: read";
    echo "    w: write";
    echo "    x: execute";
    echo "    s: sticky bit with execute (setuid bit for user, setgid bit for group, no meaning for others)";
    echo "    S: sticky bit without execute (setuid bit for user, setgid bit for group, no meaning for others)";
    echo "       -> Don't use S/s without reading up on them."
    echo "  so:";
    echo "    Read (r) + Nothing (nothing        == r";
    echo "    Read (r) + Execute (x)             == rx";
    echo "    Read (r) + Write (w)               == rw";
    echo "    Read (r) + Write (w) + Execute (x) == rwx";
    echo ""
    echo "  You can use equals (=) to set, plus (+) to add, and minus (-) to remove permissions."
    echo "  Equals sets to the exact value specified, plus only adds what is specified, and"
    echo "  minus only removes what is specified. Any non-conflicting combination of these can be used."
    echo "  some examples with the full Octal code can be read as:";
    echo "    a=rwx         : Set Read+Write+Execute (rwx) for All Users (User+Group+Others)";
    echo "    a+rx,u+w,go-w : Add Read+Execute (rx) for All Users (User+Group+Others), Add Write for User (u+w), ";
    echo "                    and Remove Write for Group and Others (go-w)";
    echo "    u=rwx,go=rx   : Set Read+Write+Execute for User(u=rwx), Read+Execute for Group/Others (go=rx)";
    echo "    ug=rwx,o=r    : Set Read+Write+Execute for User/Group (ug=rwx), Read for Others (o=r)";
    echo "    u=rw,g=r,o=   : Set Read+Write for User (u=rw), Read for Group (g=r), no perms for Others (o=)";
    echo "    a-x,u+rw,g+r,g-w,o-rw   : Remove execute for all (a-x), add Read+Write for User (u+rw),";
    echo "                              add Read for Group (g+r), remove Write for Group (g-w),";
    echo "                              remove Read+Write for Others (o-rw)";
    echo "";
    echo " # Permission Abbreviation Examples";
    echo "  chmod a=      FILE => ---------- FILE ";
    echo "  chmod a=x     FILE => ---x--x--x FILE ";
    echo "  chmod a=r     FILE => -r--r--r-- FILE ";
    echo "  chmod a=w     FILE => --w--w--w- FILE ";
    echo "  chmod a=rw    FILE => -rw-rw-rw- FILE ";
    echo "  chmod a=rwx   FILE => -rwxrwxrwx FILE ";
    echo "  chmod u=x     FILE => ---x------ FILE ";
    echo "  chmod u=w     FILE => --w------- FILE ";
    echo "  chmod u=wx    FILE => --wx------ FILE ";
    echo "  chmod u=r     FILE => -r-------- FILE ";
    echo "  chmod u=rx    FILE => -r-x------ FILE ";
    echo "  chmod u=rw    FILE => -rw------- FILE ";
    echo "  chmod u=rwx   FILE => -rwx------ FILE ";
    echo "  chmod gu=wrx  FILE => -rwxrwx--- FILE ";
    echo "  chmod ugo=xrw FILE => -rwxrwxrwx FILE ";
    echo "";
}
function referenceOctalPermissions() {
    echo "Octal Permission Examples:";
    echo "====================================";
    echo "  chmod 000 FILE => ---------- FILE ";
    echo "  chmod 100 FILE => ---x------ FILE ";
    echo "  chmod 200 FILE => --w------- FILE ";
    echo "  chmod 300 FILE => --wx------ FILE ";
    echo "  chmod 400 FILE => -r-------- FILE ";
    echo "  chmod 500 FILE => -r-x------ FILE ";
    echo "  chmod 600 FILE => -rw------- FILE ";
    echo "  chmod 700 FILE => -rwx------ FILE ";
    echo "";
    echo "Common Octal Permissions:";
    echo "====================================";
    echo "  chmod 400 FILE => -r-------- FILE ";
    echo "  chmod 440 FILE => -r--r----- FILE ";
    echo "  chmod 444 FILE => -r--r--r-- FILE ";
    echo "";
    echo "  chmod 500 FILE => -r-x------ FILE ";
    echo "  chmod 540 FILE => -r-xr----- FILE ";
    echo "  chmod 544 FILE => -r-xr--r-- FILE ";
    echo "  chmod 550 FILE => -r-xr-x--- FILE ";
    echo "  chmod 554 FILE => -r-xr-xr-- FILE ";
    echo "  chmod 555 FILE => -r-xr-xr-x FILE ";
    echo "";
    echo "  chmod 600 FILE => -rw------- FILE ";
    echo "  chmod 640 FILE => -rw-r----- FILE ";
    echo "  chmod 644 FILE => -rw-r--r-- FILE ";
    echo "  chmod 660 FILE => -rw-rw---- FILE ";
    echo "  chmod 664 FILE => -rw-rw-r-- FILE ";
    echo "  chmod 666 FILE => -rw-rw-rw- FILE ";
    echo "";
    echo "  chmod 700 FILE => -rwx------ FILE ";
    echo "  chmod 740 FILE => -rwxr----- FILE ";
    echo "  chmod 744 FILE => -rwxr--r-- FILE ";
    echo "  chmod 750 FILE => -rwxr-x--- FILE ";
    echo "  chmod 755 FILE => -rwxr-xr-x FILE ";
    echo "  chmod 770 FILE => -rwxrwx--- FILE ";
    echo "  chmod 775 FILE => -rwxrwxr-x FILE ";
    echo "  chmod 777 FILE => -rwxrwxrwx FILE ";
    echo "";
}
function referenceVim() {
    echo 'Vi/Vim Cheatsheet';
    echo '======================================================================';
    echo 'Exit file if no changes made                       -    :q';
    echo 'Exit file and discard changes                      -    :q!';
    echo 'Save (Write) file and exit                         -    :x';
    echo 'Save (Write) file and exit                         -    :wq';
    echo 'Save (Write) file and exit                         -    :ZZ';
    echo 'Save (Write) file                                  -    :w';
    echo 'Save (Write) to a new file                         -    :w newfile';
    echo 'Discard changes (reload saved file)                -    :e!';
    echo '';
    echo 'Enter INSERT mode                                  -    i';
    echo 'Exit  INSERT mode                                  -    Esc';
    echo '';
    echo 'Non-Insert mode (aka normal mode) commands:';
    echo '----------------------------------------------------------------------';
    echo 'Delete single line at caret                        -    dd';
    echo 'Delete 10 lines starting at caret                  -    10dd';
    echo 'Yank (copy) a single line at caret                 -    yy';
    echo 'Yank (copy) 10 lines starting at caret             -    10yy';
    echo 'Paste yanked (copied) line(s) after line at caret  -    (lowercase) p';
    echo 'Paste yanked (copied) line(s) before line at caret -    (uppercase) P';
    echo '';
    echo 'Go to line number 14                               -    :14';
    echo '';
    echo 'Search by POSIX regex pattern                      -    :/pattern';
    echo 'Find next occurrence of pattern                    -    (lowercase) n';
    echo 'Find previous occurrence of pattern                -    (uppercase) N';
    echo 'Replace all occurrences of pattern with replace    -    :%s/pattern/replace/g';
    echo 'Replace all but with confirmations                 -    :%s/pattern/replace/gc';
    echo '';
    echo 'Go to start of line                                -    ^';
    echo 'Go to end of line                                  -    $';
    echo '';
    echo 'Undo last command                                  -    u';
    echo 'Redo last undo                                     -    Ctrl+U';
    echo '';
    echo 'Indent line by one tab character                   -    >';
    echo 'Un-indent line by one tab character                -    <';
    echo '----------------------------------------------------------------------';
    echo 'VIMRC (~/.vimrc):'
    echo '----------------------------------------------------------------------';
    echo '# Note that .vimrc only recognizes lines starting with a double-quote character (") as comment lines';
    echo '# BUT I will be also be intermittently using pound sign (#) as a comment here. If you use # in ~/.vimrc';
    echo '# it will not be treated as a comment and will cause an error.';
    echo '# Also any of these commands can also be set/overridden in normal mode by preceding the command with a colon.';
    echo '#     e.g. :set number';
    echo '# The colon is allowed but optional in the .vimrc file';
    echo '';
    echo '" leave this alone - compatible disables lots of vim features and puts it in backwards compatible mode';
    echo 'set nocompatible';
    echo '';
    echo '" Remap Ctrl+S to write (:w) to avoid locking terminal. Note: if this happens use Ctrl+Q to resume.';
    echo '" May also require dealing with stty issues by adding the following to ~/.bashrc: stty -ixon';
    echo ':nnoremap <c-s> :w<CR>';
    echo ':inoremap <c-s> <Esc>:w<CR>a';
    echo '';
    echo '" Make backspace work like in most other editors';
    echo "" May also require dealing with stty issues by adding the following to ~/.bashrc: stty erase '^?'";
    echo 'set backspace=indent,eol,start';
    echo '';
    echo '#See http://vimcasts.org/episodes/tabs-and-spaces/';
    echo 'set tabstop=4      # Specifies the displayed width of a tab character, in spaces';
    echo 'set expandtab      # When enabled, causes spaces to be used in place of tab characters';
    echo 'set noexpandtab    # To explicitly disable expandtab (it is disabled by default)';
    echo 'set softtabstop=0  # fine tunes the amount of whitespace to be inserted in normal mode and number of spaces to delete with backspace when using expandtab.';
    echo 'set shiftwidth=4   # defines the amount of whitespace to be inserted during auto-indents.';
    echo '';
    echo 'softtabstop can also be abbreviated as sts such as set sts=0';
    echo 'tabstop can also be abbreviated as ts such as set ts=4';
    echo 'shiftwidth can also be abbreviated as sw such as set sts=4';
    echo '';
    echo '# If you prefer to work with tab characters then it is a good idea to ensure that tabstop == softtabstop';
    echo '# If you prefer to work with spaces, then it is preferable to ensure that softtabstop == shiftwidth. This way, you can expect the same number of spaces to be inserted whether you press the tab key in insert mode, or use the indentation commands in normal/visual modes.';
    echo '';
    echo '" Recommended setting for users who prefer to use tabs most of the time:';
    echo '" Make tabs 4 spaces wide and do not replace tabs with spaces';
    echo 'set tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab';
    echo '';
    echo '" Permanently enable line numbers in margin. note that these are included when copying text from terminal.';
    echo 'set number';
    echo '';
    echo '" Enable syntax highlighting';
    echo 'syntax on';
    echo '';
    echo '" Fix bug in newer versions of vim where it ignores "highlight Comment"';
    echo '" https://vi.stackexchange.com/questions/4044/vimrc-contents-selectively-i-e-highlight-ignored';
    echo 'set background=light';
    echo '';
    echo '" Change the color of commented blocks to green (default is a light blue very similar to variable names)';
    echo ':highlight Comment ctermfg=DarkGreen';
    echo '';
}
function referenceSecureDelete() {
    echo 'There are several tools for securely deleting files/folders under Linux.';
    echo 'Here are some examples:';
    echo '';
    echo '# secure delete a single file';
    echo 'wipe filename';
    echo '';
    echo '# secure delete a file, overwriting 200 times instead of the default 25';
    echo 'shred -n 200 file';
    echo '';
    echo '# secure delete a file, overwrite with zeros to hide overwriting; do 200 times';
    echo 'shred -zu -n 200 file';
    echo '';
    echo '# sudo apt-get install secure-delete';
    echo '# remove files or directories securely';
    echo '# (-v is verbose; -z wipes using zeros for the last write to hide overwriting)';
    echo 'srm -vzr folder';
    echo 'srm -vzr folder1 folder2 folder3 ...';
    echo '';
    echo '';

}
#==========================================================================
# End Section: Reference functions
#==========================================================================
