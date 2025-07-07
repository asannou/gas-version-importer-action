# Import Google Apps Script Versions to Git

This GitHub Action imports the version history of a Google Apps Script project into a Git repository. It creates a new commit for each version, preserving the creation date and description.

This action uses [clasp](https://github.com/google/clasp), the command-line tool for Google Apps Script.

## Usage

To use this action in your workflow, add the following step:

```yaml
name: Import GAS Versions

on:
  workflow_dispatch:

jobs:
  import:
    runs-on: ubuntu-latest
    steps:
      - name: Import GAS Versions
        uses: asannou/gas-version-importer-action@v1
        with:
          script_id: 'YOUR_SCRIPT_ID' # Replace with your Google Apps Script ID
          author_name: 'Your Name' # Optional: Defaults to the user who triggered the workflow
          author_email: 'your.email@example.com' # Optional: Defaults to the user who triggered the workflow
          
          CLASP_REFRESH_TOKEN: ${{ secrets.CLASP_REFRESH_TOKEN }}
          CLASP_CLIENT_ID: ${{ secrets.CLASP_CLIENT_ID }}
          CLASP_CLIENT_SECRET: ${{ secrets.CLASP_CLIENT_SECRET }}
```

### Inputs

| Name                  | Description                                       | Required |
| --------------------- | ------------------------------------------------- | -------- |
| `script_id`           | The ID of the Google Apps Script project.         | `true`   |
| `author_name`         | The name of the commit author (optional).         | `false`  |
| `author_email`        | The email of the commit author (optional).        | `false`  |
| `github_token`        | The GitHub token to use for pushing to the repository. | `true`   |
| `CLASP_REFRESH_TOKEN` | The refresh token for `clasp`.                    | `true`   |
| `CLASP_CLIENT_ID`     | The client ID for `clasp`.                        | `true`   |
| `CLASP_CLIENT_SECRET` | The client secret for `clasp`.                    | `true`   |

### Secrets

You need to configure the following secrets in your repository for this action to work:

*   `CLASP_REFRESH_TOKEN`: The refresh token obtained from `clasp login`.
*   `CLASP_CLIENT_ID`: The client ID obtained from `clasp login`.
*   `CLASP_CLIENT_SECRET`: The client secret obtained from `clasp login`.

These secrets are stored in your local `~/.clasprc.json` file after you run `clasp login`.