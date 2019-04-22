helper build_executable

mt_llvm_svn2git_init() {
    [ -n "$MT_SVN2GIT_INIT_ONCE" ] && return 0
    MT_SVN2GIT_INIT_ONCE=1

    local file
    local ref=refs/mt/svn2git
    local d
    d="$(run mktemp -d -t mt-llvm-svn2git)" ||
        error "could not create tempdir"
    file="$d"/svn2git.db
    MT_SVN2GIT_FILE="$file"

    local sha1 oldsha1 status=0
    if sha1=$(run --hide-errors git rev-parse $ref^{blob}); then
        MT_SVN2GIT_SHA1=$sha1
        local gitfile=$(cd "$d" &&
            run git --git-dir "$GIT_DIR" unpack-file $sha1) ||
            error "could not unpack $sha1 from $ref"
        run mv "$d/$gitfile" "$file" ||
            error "could not rename unpacked $sha1 from $ref"
    else
        local svn2git
        svn2git="$(build_executable svn2git)" ||
            error "could not build or find svn2git"
        run "$svn2git" create "$MT_SVN2GIT_FILE"
        status=$?
        MT_SVN2GIT_SHA1=0000000000000000000000000000000000000000
    fi
    mt_register_paths_to_clean_up "$d"
    return $status
}

mt_llvm_svn2git_save() {
    local sha1
    sha1=$(run git hash-object -w -- "$MT_SVN2GIT_FILE") ||
        error "could not hash mt-svn2git db"

    local ref=refs/mt/svn2git
    run git update-ref $ref $sha1 $MT_SVN2GIT_SHA1 ||
        error "could not save mt-svn2git to $ref; updated by another job?"
}

mt_llvm_svn2git() {
    local rev="$1"

    local svn2git
    svn2git="$(build_executable svn2git)" ||
        error "could not build or find svn2git"
    run "$svn2git" lookup "$MT_SVN2GIT_FILE" "$rev"
}

mt_llvm_svn2git_insert() {
    local svn2git
    svn2git="$(build_executable svn2git)" ||
        error "could not build or find svn2git"
    local count
    [ "$#" -le 0 ] || count="$(run git rev-list --count "$@")"
    run "$svn2git" insert "$MT_SVN2GIT_FILE" $count
}

MT_LLVM_SVN2GIT_SKIP=afb1d31c54204b7f6c11e4f8815d203bcf9cffa3
mt_llvm_svn2git_is_commit_mapped() {
    local commit="$1"

    # Clump skipped commits with their parents.
    local rev
    if [ "$commit" = $MT_LLVM_SVN2GIT_SKIP ]; then
        rev=$(mt_llvm_svn $commit^) ||
            error "unexpected missing SVN rev for $commit^"
    elif [ -n "$commit" ]; then
        rev=$(mt_llvm_svn $commit) ||
            error "unexpected missing SVN rev for $commit"
    fi

    # TODO: write testcase that would catch passing "$1" here instead of "$rev".
    mt_llvm_svn2git "$rev" >/dev/null 2>&1
}