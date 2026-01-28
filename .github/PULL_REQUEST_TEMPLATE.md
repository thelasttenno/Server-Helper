# Pull Request

## Description

Provide a clear and concise description of your changes.

**What does this PR do?**

**Why is this change needed?**

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Code refactoring (no functional changes)
- [ ] Configuration change
- [ ] Performance improvement
- [ ] Security fix

## Related Issues

Closes #(issue number)
Fixes #(issue number)
Related to #(issue number)

## Changes Made

List the specific changes in this PR:

- [ ] Added/Modified role: `roles/role_name/`
- [ ] Updated playbook: `playbooks/playbook_name.yml`
- [ ] Modified configuration: `group_vars/all.yml`
- [ ] Updated documentation: `docs/...`
- [ ] Added tests
- [ ] Other (describe):

## Testing Performed

### Test Environment

**Operating System:**
- [ ] Ubuntu 24.04 LTS
- [ ] Ubuntu 22.04 LTS
- [ ] Other (specify):

**Test Type:**
- [ ] Fresh installation
- [ ] Upgrade from previous version
- [ ] Existing deployment

### Test Results

<details>
<summary>Test Output</summary>

```bash
# Paste ansible-playbook output here
```

</details>

### Idempotency Test

- [ ] Playbook runs successfully on first execution
- [ ] Playbook shows no changes on second execution (idempotent)

### Functionality Tests

Describe how you tested the functionality:

1. **Test 1:** Description
   - Steps: ...
   - Expected: ...
   - Actual: ...
   - Result: ✅ Pass / ❌ Fail

2. **Test 2:** Description
   - Steps: ...
   - Expected: ...
   - Actual: ...
   - Result: ✅ Pass / ❌ Fail

## Configuration Changes

### New Variables

List any new configuration variables added:

```yaml
# group_vars/all.yml
new_feature:
  enabled: true
  option: "value"
```

### Breaking Changes

- [ ] This PR introduces breaking changes

**If yes, describe the breaking changes and migration steps:**

1.
2.
3.

## Documentation

- [ ] README.md updated
- [ ] CHANGELOG.md updated
- [ ] Configuration examples updated (`group_vars/all.example.yml`)
- [ ] New documentation added to `docs/`
- [ ] Code comments added for complex logic
- [ ] No documentation needed

## Security Considerations

- [ ] No secrets committed (passwords, API keys, tokens)
- [ ] Ansible Vault used for sensitive data
- [ ] Security implications considered
- [ ] No new security vulnerabilities introduced

## Checklist

### Code Quality

- [ ] Code follows the project's coding standards
- [ ] Self-review of code completed
- [ ] Comments added for complex or unclear code
- [ ] No unnecessary files or changes included
- [ ] Linting passed (`ansible-lint`, `yamllint`)

### Testing

- [ ] Tested on clean Ubuntu 24.04 LTS system
- [ ] Playbooks are idempotent
- [ ] All services start correctly
- [ ] No errors in logs
- [ ] Backward compatibility maintained (if applicable)

### Documentation

- [ ] Documentation updated to reflect changes
- [ ] Configuration examples are accurate
- [ ] Commit messages are clear and descriptive

### Dependencies

- [ ] No new dependencies added
- [ ] OR: New dependencies documented in `requirements.yml`/`requirements.txt`

## Screenshots (if applicable)

Add screenshots to demonstrate UI changes or new dashboards.

## Additional Notes

Add any additional information that reviewers should know:

- Known limitations:
- Future improvements:
- Alternative approaches considered:

## Deployment Notes

Special instructions for deploying this change:

```bash
# Example commands or manual steps needed
```

## Reviewer Checklist (for maintainers)

- [ ] Code quality meets standards
- [ ] Tests are adequate
- [ ] Documentation is complete
- [ ] No security concerns
- [ ] Backward compatibility maintained
- [ ] Ready to merge

---

**Thank you for contributing to Server Helper!** 🎉
