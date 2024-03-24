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
    rm ~/my_commands
    # rm ~/nix_develop_fail
    # rm ~/poetry_add_fail
    rm -rf ~/poetry2nix-testing_*
    latest_reached=false
    latest=$(cat ~/poetry2nix-testing/latest)
    for quoted_package in $packages
    do
        unquoted_package=${quoted_package//\"}
        if [ "$latest" = $unquoted_package ]; then
            latest_reached=true
        fi
        if [ "$latest_reached" = true ]; then
            echo "going to check $unquoted_package "
            echo "source ~/poetry2nix-testing/script.sh; test_package $unquoted_package" >> ~/my_commands
        else
            echo "$unquoted_package already analyzed"
        fi
    done
    cat ~/my_commands | parallel
}

test_package() {
    quoted_package=$1
    unquoted_package=${quoted_package//\"}
    cp -r ~/poetry2nix-testing-without_json ~/poetry2nix-testing_$unquoted_package
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
        echo $unquoted_package > ~/poetry2nix-testing/latest
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

install_poetry_package() {
    quoted_package=$1
    unquoted_package=${quoted_package//\"}
    mkdir -p fail_logs/$unquoted_package
    cd fail_logs/$unquoted_package
    cp ../../flake.nix .
    cp ../../flake.lock .
    cp ../../poetry.lock .
    cp ../../pyproject.toml .
    git aa
    poetry add $unquoted_package
    rc=$?
    if [[ $rc != 0 ]]; then
        echo Package $unquoted_package failed to install with poetry
        echo $unquoted_package >> ../../poetry_add_fail_2
    else
        set -o pipefail
        nix develop --command echo "Nix develop environment ready" |& tee ${unquoted_package}_nix.log
        rc=$?
        if [[ $rc != 0 ]]; then
            grep "For full logs" ${unquoted_package}_nix.log | grep -o nix.*drv > generate_${unquoted_package}_log.sh
            bash generate_${unquoted_package}_log.sh > ${unquoted_package}.log
            git aa
            echo Package $unquoted_package failed to install with nix develop
            echo $unquoted_package > ../../nix_develop_fail_2
        else
            echo $unquoted_package > ../../works
        fi
        git cm $unquoted_package
    fi
    cd ../..
}

install_with_fixes() {
    package=$1
    max_attempts=3  # Set the maximum number of attempts here
    attempt=0  # Start with attempt 0 since the first try is outside the loop

    # Initial attempt to install the package before entering the loop
    install_poetry_package "$package"
    result_file="fail_logs/$package/${package}.log"

    # Enter the loop if the initial attempt fails (i.e., if an error log exists)
    while [ -f "$result_file" ] && [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts for package $package."

        # Apply heuristic fix using the Python script
        python fix_heuristic.py "$result_file"
        fix_status=$?

        # After applying fixes, attempt to reinstall the package
        install_poetry_package "$package"
        new_error_content=$(cat "$result_file")

        if [ $fix_status -ne 0 ]; then
            echo "Could not apply fix heuristic to package $package, exiting."
            return 1
        elif [ -z "$new_error_content" ]; then
            echo "Package $package installed successfully after applying fixes."
            git add poetry2nix
            git commit -m "Applied autofix"
            return 0
        elif [ "$error_content" = "$new_error_content" ]; then
            echo "The same error persists after applying fix heuristic to package $package, cannot fix."
            return 1
        else
            echo "A different error was encountered after applying fix heuristic, attempting again."
            # Update error_content for the next iteration comparison
            error_content=$new_error_content
            echo "Donde cojones estoyyyyyyyyyyyyyyy"
            pwd
            git add poetry2nix
            git commit -m "Applied autofix"
        fi
    done

    if [ ! -f "$result_file" ]; then
        echo "Package $package installed successfully."
        return 0
    else
        echo "Maximum attempts reached or package $package could not be installed."
        return 1
    fi
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
