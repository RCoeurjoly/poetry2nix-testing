check_uninstallable_packages () {
    for branch in $(git branch --no-color | grep -v "main")
    do
        git show --pretty="" --name-only $branch | grep -q uninstallable
        rc=$?
        if [[ $rc = 0 ]]; then
            echo $branch
        fi
    done
}

test_packages () {
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # If no argument, parse big json
    if [ "$#" -eq 0 ]; then
        packages=$(cat packages.json | jq .rows[].project)
    fi

    while getopts ":f:p:h" o; do
        case "${o}" in
            f)
                packages=$(cat "$OPTARG" | jq .rows[].project)
                ;;
            p)
                packages="$OPTARG"
                ;;
            h)
                echo usage
                ;;
            *)
                echo fail
                ;;
        esac
    done

    shift $((OPTIND-1))

    for quoted_package in $packages
    do
        unquoted_package=${quoted_package//\"}
        git rev-parse --quiet --verify $unquoted_package
        rc=$?
        if [[ $rc = 0 ]]; then
            echo Package $unquoted_package is already handled
        else
            git checkout -b $unquoted_package
            git push origin --delete $unquoted_package
            poetry add $unquoted_package
            rc=$?
            if [[ $rc != 0 ]]; then
                echo Package $unquoted_package failed to install with poetry
                add_package_to_uninstallable_list $unquoted_package
                git checkout main
                git merge $unquoted_package
                git branch -d $unquoted_package
            else
                git add --all
                git commit -m $unquoted_package
                git push
                git checkout main
            fi
        fi
    done
}

test_packages_locally () {
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # If no argument, parse big json
    if [ "$#" -eq 0 ]; then
        packages=$(cat top-pypi-packages-30-days.min.json | jq .rows[].project)
    fi

    while getopts ":f:p:h" o; do
        case "${o}" in
            f)
                packages=$(cat "$OPTARG" | jq .rows[].project)
                ;;
            p)
                packages="$OPTARG"
                ;;
            h)
                echo usage
                ;;
            *)
                echo fail
                ;;
        esac
    done

    shift $((OPTIND-1))

    for quoted_package in $packages
    do
        unquoted_package=${quoted_package//\"}
        poetry add $unquoted_package
        rc=$?
        if [[ $rc != 0 ]]; then
            echo Package $unquoted_package failed to install with poetry
            echo $unquoted_package >> poetry_add_fail
        else
            nix develop --command echo "Nix develop environment ready"
            rc=$?
            if [[ $rc != 0 ]]; then
                echo Package $unquoted_package failed to install with nix develop
                echo $unquoted_package >> nix_develop_fail
            fi
            poetry remove $unquoted_package
        fi
        git checkout -- poetry.lock pyproject.toml
    done
}

test_packages_locally_parallel () {
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # If no argument, parse big json
    if [ "$#" -eq 0 ]; then
        packages=$(cat top-pypi-packages-30-days.min.json | jq .rows[].project)
    else
        packages=$(cat $1 | jq .rows[].project)
    fi

    while getopts ":f:p:h" o; do
        case "${o}" in
            f)
                packages=$(cat "$OPTARG" | jq .rows[].project)
                ;;
            p)
                packages="$OPTARG"
                ;;
            h)
                echo usage
                ;;
            *)
                echo fail
                ;;
        esac
    done

    shift $((OPTIND-1))

    for quoted_package in $packages
    do
        unquoted_package=${quoted_package//\"}
        echo "test_package $unquoted_package" >> ~/my_commands
    done
    source ~/poetry2nix-testing/script.sh
    cat ~/my_commands | parallel
}

test_package() {
    quoted_package=$1
    unquoted_package=${quoted_package//\"}
    git clone -b without_json git@github.com:RCoeurjoly/poetry2nix-testing.git ~/poetry2nix-testing_$unquoted_package
    cd ~/poetry2nix-testing_$unquoted_package
    poetry add $unquoted_package
    rc=$?
    if [[ $rc != 0 ]]; then
        echo Package $unquoted_package failed to install with poetry
        echo $unquoted_package >> ~/poetry_add_fail
    else
        nix develop --command echo "Nix develop environment ready"
        rc=$?
        if [[ $rc != 0 ]]; then
            echo Package $unquoted_package failed to install with nix develop
            echo $unquoted_package >> ~/nix_develop_fail
        fi
        poetry remove $unquoted_package
        # nix-collect-garbage
    fi
}

test_packages_simple () {
    OPTIND=1         # Reset in case getopts has been used previously in the shell.

    # If no argument, parse big json
    if [ "$#" -eq 0 ]; then
        packages=$(cat packages.json | jq .rows[].project)
    fi

    while getopts ":f:p:h" o; do
        case "${o}" in
            f)
                packages=$(cat "$OPTARG" | jq .rows[].project)
                ;;
            p)
                packages="$OPTARG"
                ;;
            h)
                echo usage
                ;;
            *)
                echo fail
                ;;
        esac
    done

    shift $((OPTIND-1))

    for quoted_package in $packages
    do
        unquoted_package=${quoted_package//\"}
        git rev-parse --quiet --verify $unquoted_package
        rc=$?
        if [[ $rc = 0 ]]; then
            echo Package $unquoted_package is already handled
        else
            git checkout -b $unquoted_package
            git push -f
        fi
    done
}

add_package_to_uninstallable_list() {
    uninstallable_package=$1
    echo $uninstallable_package >> uninstallable_packages
    git checkout -- poetry.lock
    git add uninstallable_packages
    git commit -m \""Uninstallable $uninstallable_package"\"
}

uninstall_poetry_packages() {
    for branch in $(git branch --no-color | grep -v "main")
    do
        git checkout $branch
        poetry remove $branch
        git checkout -- .
    done
}
