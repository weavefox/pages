# WeaveFox Pages Deploy Action

Build your site in CI, upload the artifact zip to WeaveFox Pages, and deploy it as the live version.

The action runs `upload-token` → `upload-artifact-zip` → `create version` → `deploy version` and stops at the first failing call.

## Usage

```yaml
name: Deploy

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile
      - run: pnpm build

      - uses: weavefox/pages@v1
        with:
          api-key: ${{ secrets.WEAVEFOX_API_KEY }}
          public-id: weavefox-test-app
          dist-dir: dist
          changelog: ${{ github.event.head_commit.message }}
```

`WEAVEFOX_API_KEY` is created on the WeaveFox API Key page and stored as a repository secret. `public-id` is the `publicId` of your WeaveFox Pages app; the example uses `weavefox-test-app`.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `api-key` | yes | | WeaveFox API key, sent as the Bearer token |
| `public-id` | yes | | `publicId` of the target WeaveFox Pages app |
| `dist-dir` | no | `dist` | Directory containing the build output; must include `index.html` |
| `changelog` | no | `Deploy <sha> from <repo>` | Version changelog, 1-2000 characters |

## Outputs

| Output | Description |
| --- | --- |
| `version` | Version created for this deployment |
| `artifact-zip-url` | URL of the uploaded artifact zip |

## Build output requirements

WeaveFox Pages serves the artifact from a storage sub path, so absolute asset paths such as `/assets/index.js` resolve to the storage root and return 404. Configure relative paths before building:

| Tool | Config |
| --- | --- |
| Vite | `base: './'` in `vite.config.ts` |
| Next.js (static export) | `assetPrefix: './'` in `next.config.js` |
| webpack | `output.publicPath: './'` |
| Nuxt | `app.baseURL: './'` in `nuxt.config.ts` |

After this change `index.html` references `./assets/...` instead of `/assets/...`.

## Requirements

- Runner: `ubuntu-latest` or `macos-latest`. `curl`, `jq` and `zip` are preinstalled there; Windows runners are not supported because `zip` is not available in git-bash.
- The app must already exist. The action does not create it.
- The artifact zip is limited to 5MB by the upload API.

## Troubleshooting

**`POST upload-artifact-zip failed`** — usually the zip exceeds the 5MB limit. Drop source maps, unused assets and large images, or move heavy media to external storage.

**Deployed page returns 404 for assets** — set the build base to `./` as described above and rebuild.

**`HTTP 401`** — the API key is invalid or expired. Recreate it and refresh the repository secret.

## Publishing to Marketplace

The action is publishable as-is: `action.yml` defines `name`, `description` and `branding`. Push a semver tag, create a release with the tag `v1` (also keep a moving `v1` tag for consumers), and tick "Publish this Action to the GitHub Marketplace" in the release form.

## License

MIT. See [LICENSE](LICENSE).
