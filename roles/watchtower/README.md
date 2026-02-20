# Watchtower Role

Deploys [Watchtower](https://containrrr.dev/watchtower/) to automatically update running Docker containers.

## Features

- **Automated Updates**: Checks for new images on a schedule.
- **Cleanup**: Removes old images after update.
- **Notifications**: Sends alerts on successful/failed updates (via Shoutrrr).

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `target_watchtower.schedule` | `0 0 4 * * *` | Cron schedule (4 AM daily) |
| `target_watchtower.cleanup` | `true` | Prune old images |
| `target_watchtower.notifications` | `false` | Enable notifications |

## Notifications

To enable notifications:

1. Set `target_watchtower.notifications: true` in `group_vars/targets.yml` (or `control.yml`).
2. Define `vault_watchtower_notification_url` in your vault (e.g., `discord://token@id`).
