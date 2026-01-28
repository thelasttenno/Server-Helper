# Release Process

This document describes the automated release process for Server Helper.

## Semantic Versioning

Server Helper follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** version (v2.0.0): Incompatible API changes or breaking changes
- **MINOR** version (v1.1.0): New features, backwards-compatible
- **PATCH** version (v1.0.1): Bug fixes, backwards-compatible

## Release Workflow

### 1. Update CHANGELOG.md

Before creating a release, ensure the CHANGELOG.md is updated:

```bash
# Edit CHANGELOG.md
nano CHANGELOG.md
```

Move items from "Unreleased" to a new version section:

```markdown
## Unreleased

(empty or work in progress)

---

## Version 1.1.0 - Feature Name (2025-01-15)

### Added
- New feature A
- New feature B

### Fixed
- Bug fix C
```

### 2. Commit Changelog

```bash
git add CHANGELOG.md
git commit -m "docs: Update changelog for v1.1.0"
git push origin main
```

### 3. Create Release Tag

```bash
# Create and push tag
git tag -a v1.1.0 -m "Release v1.1.0: Feature Name"
git push origin v1.1.0
```

### 4. Automated Release Creation

Once the tag is pushed, GitHub Actions automatically:

1. ✅ Extracts changelog for this version
2. ✅ Creates GitHub Release with release notes
3. ✅ Attaches documentation files
4. ✅ Generates additional release notes from PRs

**View the release at:** `https://github.com/thelasttenno/Server-Helper/releases`

## PR Label Guidelines

Use these labels on pull requests to automatically categorize them in release notes:

| Label | Category | When to Use |
|-------|----------|-------------|
| `feature`, `enhancement`, `feat` | 🎉 New Features | Adding new functionality |
| `bug`, `fix`, `bugfix` | 🐛 Bug Fixes | Fixing issues |
| `security`, `vulnerability` | 🔒 Security Fixes | Security patches |
| `documentation`, `docs` | 📚 Documentation | Docs changes |
| `configuration`, `config` | 🔧 Configuration | Config changes |
| `performance`, `optimization` | ⚡ Performance | Speed/efficiency improvements |
| `refactor`, `refactoring` | 🧹 Code Refactoring | Code restructuring |
| `test`, `testing` | 🧪 Testing | Test additions/changes |
| `chore`, `maintenance` | 🔨 Maintenance | Routine tasks |
| `dependencies`, `deps` | 📦 Dependencies | Dependency updates |
| `breaking-change`, `breaking` | ⚠️ Breaking Changes | Incompatible changes |

**Special labels:**
- `no-changelog`: Skip changelog requirement
- `skip-changelog`: Skip in release notes
- `ignore-for-release`: Don't include in release notes

## Automated Checks

### Changelog Check (Pull Requests)

When you open a PR to `main` or `develop`, GitHub Actions checks if CHANGELOG.md was updated:

- ✅ **Pass**: CHANGELOG.md modified or exemption label present
- ⚠️ **Warning**: CHANGELOG.md not modified (comment added to PR)

**Exemption labels** (skip changelog requirement):
- `documentation` - Documentation-only changes
- `dependencies` - Dependency updates only
- `no-changelog` - Other changes that don't need changelog entry

## Version Numbering Guide

### MAJOR Version (Breaking Changes)

Increment when you make incompatible changes:

```yaml
# Example: Changing required variables
# OLD (v1.x.x)
nas:
  ip: "192.168.1.100"

# NEW (v2.0.0) - BREAKING
nas:
  shares:
    - ip: "192.168.1.100"
```

**Examples:**
- Removing configuration options
- Changing variable structure
- Removing playbooks or roles
- Incompatible with previous versions

### MINOR Version (New Features)

Increment when you add functionality in a backwards-compatible manner:

```yaml
# Example: Adding optional feature
# v1.0.0 → v1.1.0
watchtower:
  enabled: false  # NEW feature, but optional
```

**Examples:**
- Adding new roles
- Adding new playbooks
- Adding optional configuration
- New features that don't break existing setups

### PATCH Version (Bug Fixes)

Increment when you make backwards-compatible bug fixes:

**Examples:**
- Fixing broken tasks
- Correcting typos in templates
- Fixing service configurations
- Documentation fixes
- Security patches (non-breaking)

## Manual Release Steps (If Automation Fails)

If the automated workflow fails, create a release manually:

1. Go to: `https://github.com/thelasttenno/Server-Helper/releases/new`
2. Choose the tag (e.g., `v1.1.0`)
3. Set title: `Server Helper v1.1.0`
4. Copy changelog entry to description
5. Attach files (if needed)
6. Click "Publish release"

## Release Checklist

Before tagging a release, ensure:

- [ ] CHANGELOG.md updated with all changes
- [ ] Version number follows semantic versioning
- [ ] All tests passing
- [ ] Documentation updated
- [ ] Breaking changes clearly documented
- [ ] Migration guide provided (if breaking changes)
- [ ] Security considerations reviewed
- [ ] README.md version badges updated (if applicable)

## Hotfix Releases

For critical bugs in production:

1. Create hotfix branch from tag:
   ```bash
   git checkout -b hotfix/1.0.1 v1.0.0
   ```

2. Fix the bug and commit:
   ```bash
   git commit -m "fix: Critical security vulnerability"
   ```

3. Update CHANGELOG.md:
   ```markdown
   ## Version 1.0.1 - Hotfix: Security Patch (2025-01-10)

   ### Security
   - Fixed critical vulnerability in XYZ
   ```

4. Create tag and push:
   ```bash
   git tag -a v1.0.1 -m "Hotfix v1.0.1: Security Patch"
   git push origin hotfix/1.0.1
   git push origin v1.0.1
   ```

5. Merge back to main:
   ```bash
   git checkout main
   git merge hotfix/1.0.1
   git push origin main
   ```

## Release Announcement

After a release is published:

1. **GitHub Discussions**: Announce in Discussions
2. **README**: Update version badge (if present)
3. **Users**: Notify via GitHub release notification

## Troubleshooting

### Release workflow failed

Check the workflow logs:
```
https://github.com/thelasttenno/Server-Helper/actions
```

Common issues:
- Changelog section not found (check format)
- Missing GITHUB_TOKEN permissions
- Tag already exists

### Changelog not extracted correctly

Ensure changelog follows this format:

```markdown
## Version X.Y.Z - Description (YYYY-MM-DD)

### Category
- Change description
```

## Additional Resources

- [Semantic Versioning Specification](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [GitHub Release Documentation](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Conventional Commits](https://www.conventionalcommits.org/)
