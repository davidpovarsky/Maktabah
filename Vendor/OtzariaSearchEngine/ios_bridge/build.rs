use std::{env, fs, path::PathBuf};

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let upstream_dir = manifest_dir.parent().unwrap().join("Upstream");
    let commit_path = upstream_dir.join("UPSTREAM_COMMIT");
    let manifest_path = upstream_dir.join("UPSTREAM_MANIFEST.json");
    let resources_path = upstream_dir.join("RESOURCE_MANIFEST.json");

    println!("cargo:rerun-if-changed={}", commit_path.display());
    println!("cargo:rerun-if-changed={}", manifest_path.display());
    println!("cargo:rerun-if-changed={}", resources_path.display());

    let commit = fs::read_to_string(&commit_path)
        .expect("missing Upstream/UPSTREAM_COMMIT")
        .trim()
        .to_owned();
    assert!(
        commit.len() == 40 && commit.bytes().all(|b| b.is_ascii_hexdigit()),
        "UPSTREAM_COMMIT must contain one full Git SHA"
    );
    println!("cargo:rustc-env=OTZARIA_UPSTREAM_COMMIT={commit}");

    let manifest =
        fs::read_to_string(&manifest_path).expect("missing Upstream/UPSTREAM_MANIFEST.json");
    let value: serde_json::Value =
        serde_json::from_str(&manifest).expect("invalid UPSTREAM_MANIFEST.json");
    let manifest_commit = value["commit"].as_str().unwrap_or_default();
    assert_eq!(
        commit, manifest_commit,
        "manifest commit does not match UPSTREAM_COMMIT"
    );
    let synced_at = value["synced_at"].as_str().unwrap_or("unknown");
    let default_generation_order = value["default_generation_order"]
        .as_u64()
        .expect("manifest default_generation_order is missing");
    assert!(default_generation_order <= u32::MAX as u64);
    let sidecar = value["semantic_sidecar_revision"]
        .as_str()
        .unwrap_or("unknown");
    println!("cargo:rustc-env=OTZARIA_SYNCED_AT={synced_at}");
    println!("cargo:rustc-env=OTZARIA_DEFAULT_GENERATION_ORDER={default_generation_order}");
    println!("cargo:rustc-env=OTZARIA_SEMANTIC_REVISION={sidecar}");

    let resources: serde_json::Value = serde_json::from_str(
        &fs::read_to_string(resources_path).expect("missing RESOURCE_MANIFEST.json"),
    )
    .expect("invalid RESOURCE_MANIFEST.json");
    let mut hashes = serde_json::Map::new();
    for resource in resources["resources"].as_array().into_iter().flatten() {
        if let (Some(destination), Some(hash)) = (
            resource["destination"].as_str(),
            resource["sha256"].as_str(),
        ) {
            hashes.insert(
                destination.to_owned(),
                serde_json::Value::String(hash.to_owned()),
            );
        }
    }
    println!(
        "cargo:rustc-env=OTZARIA_RESOURCE_HASHES={}",
        serde_json::to_string(&hashes).unwrap()
    );
}
