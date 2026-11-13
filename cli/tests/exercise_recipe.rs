//! The AGENTS.md § Exercise recipe, run on the built binary: `zharness install`
//! then `zharness uninstall` in a fresh `git init` repository, with the root
//! resolved from the working directory and the registry under a scratch
//! `XDG_CONFIG_HOME`. The unit tests call the installer as a library on a plain
//! tempdir; this one covers argument parsing, git root resolution and the
//! recipe's "nothing left behind" outcome.
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

const INSTALLED: [&str; 4] = [
    ".gitignore",
    ".monows/PROJECT.md",
    ".monows/WORKFLOW.md",
    "AGENTS.md",
];

struct Sandbox {
    _config: tempfile::TempDir,
    repo: tempfile::TempDir,
    config: PathBuf,
}

/// Run from a Git hook, the caller's GIT_* would point the children at the
/// calling repository instead of the fixture.
fn local_git_env() -> Vec<String> {
    let out = Command::new("git")
        .args(["rev-parse", "--local-env-vars"])
        .output()
        .expect("git is on PATH");
    String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(str::to_string)
        .collect()
}

fn command(program: impl AsRef<std::ffi::OsStr>, cwd: &Path, config: &Path) -> Command {
    let mut c = Command::new(program);
    for var in local_git_env() {
        c.env_remove(var);
    }
    c.current_dir(cwd)
        .env("XDG_CONFIG_HOME", config)
        .env("HOME", config);
    c
}

fn sandbox() -> Sandbox {
    let config_dir = tempfile::tempdir().expect("scratch config dir");
    let repo = tempfile::tempdir().expect("scratch repo");
    let config = config_dir.path().to_path_buf();
    let init = command("git", repo.path(), &config)
        .args(["init", "-q"])
        .output()
        .expect("git init runs");
    assert!(init.status.success(), "git init failed: {init:?}");
    Sandbox {
        _config: config_dir,
        repo,
        config,
    }
}

fn zharness(sb: &Sandbox, cwd: &Path, verb: &str) -> Output {
    let out = command(env!("CARGO_BIN_EXE_zharness"), cwd, &sb.config)
        .arg(verb)
        .output()
        .expect("zharness runs");
    assert!(
        out.status.success(),
        "zharness {verb} exited {:?}\nstdout: {}\nstderr: {}",
        out.status.code(),
        String::from_utf8_lossy(&out.stdout),
        String::from_utf8_lossy(&out.stderr)
    );
    out
}

fn porcelain(sb: &Sandbox) -> String {
    let out = command("git", sb.repo.path(), &sb.config)
        .args(["status", "--porcelain", "--untracked-files=all"])
        .output()
        .expect("git status runs");
    String::from_utf8_lossy(&out.stdout).into_owned()
}

/// Every path in the repository outside `.git`, ignored files included.
fn tree(root: &Path) -> Vec<String> {
    fn walk(root: &Path, dir: &Path, out: &mut Vec<String>) {
        for entry in fs::read_dir(dir).expect("readable dir") {
            let p = entry.expect("dir entry").path();
            let rel = p.strip_prefix(root).unwrap().to_string_lossy().into_owned();
            if rel == ".git" {
                continue;
            }
            if p.is_dir() {
                walk(root, &p, out);
            }
            out.push(rel);
        }
    }
    let mut out = Vec::new();
    walk(root, root, &mut out);
    out.sort();
    out
}

fn registered(sb: &Sandbox) -> Vec<String> {
    fs::read_to_string(sb.config.join("zharness/repos"))
        .unwrap_or_default()
        .lines()
        .map(str::to_string)
        .collect()
}

fn canonical(p: &Path) -> String {
    fs::canonicalize(p).unwrap().to_string_lossy().into_owned()
}

#[test]
fn exercise_recipe_install_then_uninstall_leaves_nothing() {
    let sb = sandbox();
    let root = sb.repo.path();

    zharness(&sb, root, "install");
    for rel in INSTALLED {
        assert!(root.join(rel).is_file(), "install did not create {rel}");
    }
    assert_eq!(
        registered(&sb),
        [canonical(root)],
        "install did not register the repository"
    );

    zharness(&sb, root, "uninstall");
    assert_eq!(
        porcelain(&sb),
        "",
        "git status is not clean after uninstall"
    );
    assert_eq!(
        tree(root),
        Vec::<String>::new(),
        "uninstall left files behind"
    );
    assert!(
        registered(&sb).is_empty(),
        "uninstall left the repository registered"
    );
}

#[test]
fn install_from_a_subdirectory_targets_the_git_toplevel() {
    let sb = sandbox();
    let root = sb.repo.path();
    let deep = root.join("sub/deep");
    fs::create_dir_all(&deep).unwrap();

    zharness(&sb, &deep, "install");
    for rel in INSTALLED {
        assert!(
            root.join(rel).is_file(),
            "install from sub/deep did not create {rel} at the git toplevel"
        );
    }
    assert_eq!(
        tree(&deep),
        Vec::<String>::new(),
        "install wrote into the working directory instead of the toplevel"
    );
}
