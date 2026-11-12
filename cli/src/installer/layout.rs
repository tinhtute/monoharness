//! The `docs/` and `.harness/` → `.monows/` layout migrations.
//!
//! Managed files moved from `docs/` to `.harness/` in v0.31.0 and from
//! `.harness/` to `.monows/` in v0.37.0. `update` renames
//! each old path that still exists, so plan bytes never pass through a write,
//! and re-keys the base manifest, ownership ledger and captured originals to
//! the new paths. Both copies present is a conflict nobody can resolve
//! mechanically, so it refuses before anything is written.

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use super::ownership::{Ownership, KIND_FILE, OWNERSHIP_FILE};
use super::{find_original, safe_path, ORIGINAL_DIR, PROJECT_TARGET, WORKFLOW_TARGET};

pub const HARNESS_DIR: &str = ".monows";

/// The managed directory of v0.31–v0.36, removed once empty.
pub const LEGACY_HARNESS_DIR: &str = ".harness";

/// Old path → new path, files first, then the plans tree.
pub fn legacy_moves() -> [(&'static str, &'static str); 6] {
    [
        ("docs/WORKFLOW.md", WORKFLOW_TARGET),
        ("docs/PROJECT.md", PROJECT_TARGET),
        ("docs/plans", PLANS_DIR),
        (".harness/WORKFLOW.md", WORKFLOW_TARGET),
        (".harness/PROJECT.md", PROJECT_TARGET),
        (".harness/plans", PLANS_DIR),
    ]
}

/// The plans tree under the managed directory.
pub const PLANS_DIR: &str = ".monows/plans";

/// The renames `update` must make. Errors when an old path and its new path
/// both exist, or when two old paths would land on the same new path.
pub fn prepare(root: &Path) -> Result<Vec<(String, String)>, String> {
    let mut moves = Vec::new();
    for (old, new) in legacy_moves() {
        if fs::symlink_metadata(root.join(old)).is_err() {
            continue;
        }
        if let Some((prev, _)) = moves.iter().find(|(_, n)| n == new) {
            return Err(format!(
                "both {prev} and {old} exist; merge them into {prev} and remove {old}"
            ));
        }
        if fs::symlink_metadata(root.join(new)).is_ok() {
            return Err(format!(
                "both {old} and {new} exist; merge them into {new} and remove {old}"
            ));
        }
        moves.push((old.to_string(), new.to_string()));
    }
    Ok(moves)
}

/// Rename each path and re-key the bookkeeping that names it.
pub fn apply(
    root: &Path,
    moves: &[(String, String)],
    base: &mut HashMap<String, String>,
) -> Result<(), String> {
    if moves.is_empty() {
        return Ok(());
    }
    fs::create_dir_all(root.join(HARNESS_DIR)).map_err(|e| format!("create {HARNESS_DIR}: {e}"))?;
    let mut own = Ownership::load(root);
    let had_ledger = root.join(OWNERSHIP_FILE).exists();
    for (old, new) in moves {
        fs::rename(root.join(old), root.join(new))
            .map_err(|e| format!("move {old} -> {new}: {e}"))?;
        if let Some(h) = base.remove(old) {
            base.insert(new.clone(), h);
        }
        if own.has(KIND_FILE, old) {
            let origin = own.get(KIND_FILE, old);
            own.remove(KIND_FILE, old);
            own.set(KIND_FILE, new, &origin);
        }
        if let Some(p) = find_original(root, old) {
            let to = root
                .join(ORIGINAL_DIR)
                .join(format!("{}.orig", safe_path(new)));
            fs::rename(&p, &to).map_err(|e| format!("move original of {old}: {e}"))?;
        }
    }
    if had_ledger {
        own.save(root)?;
    }
    // Only an empty directory goes; anything else in it stays where it was.
    let _ = fs::remove_dir(root.join(LEGACY_HARNESS_DIR));
    Ok(())
}
