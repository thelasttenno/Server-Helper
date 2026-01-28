---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## Environment

**Server Helper Version:**
- [ ] v1.0.0
- [ ] main branch (specify commit: )
- [ ] Other (specify: )

**Operating System:**
- [ ] Ubuntu 24.04 LTS
- [ ] Ubuntu 22.04 LTS
- [ ] Other (specify: )

**Ansible Version:**
```
ansible --version
```

**Python Version:**
```
python3 --version
```

## Steps to Reproduce

1. Run command: `...`
2. Configure setting: `...`
3. Execute playbook: `...`
4. See error

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

A clear description of what actually happened.

## Logs and Output

<details>
<summary>Ansible Playbook Output</summary>

```
Paste the output here
```

</details>

<details>
<summary>Error Messages</summary>

```
Paste error messages here
```

</details>

<details>
<summary>Relevant Configuration</summary>

```yaml
# Paste relevant parts of group_vars/all.yml
# IMPORTANT: Remove any sensitive information!
```

</details>

## Screenshots

If applicable, add screenshots to help explain your problem.

## Additional Context

Add any other context about the problem here. For example:
- Is this a fresh installation or existing setup?
- Did this work in a previous version?
- Are you using any custom roles or modifications?
- Network environment (behind proxy, firewall, etc.)?

## Possible Solution

If you have ideas on how to fix the issue, please share them here.

## Checklist

- [ ] I have searched existing issues to ensure this is not a duplicate
- [ ] I have tested on a clean Ubuntu 24.04 LTS system
- [ ] I have included relevant logs and configuration
- [ ] I have removed sensitive information from logs/config
- [ ] I have tried running the playbook with `-vvv` for verbose output
