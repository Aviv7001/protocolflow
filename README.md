# ProtocolFlow

ProtocolFlow is a Flutter app for creating, editing, importing, running, and exporting protocol JSON files. The web build is designed to run fully in the browser: no Firebase, Supabase, backend, database, login, or cloud storage is required.

## Local Development

Install dependencies:

```sh
flutter pub get
```

Run the app locally in a browser:

```sh
flutter run -d chrome
```

Build the web app for local testing at the site root:

```sh
flutter build web --release --base-href /
```

The compiled files are written to `build/web`.

## JSON Import and Export

Use the Library menu to import or export JSON.

Import reads a local `.json` file selected from your computer and stores the imported protocol data in the browser's local app storage. Export serializes the edited protocol data and downloads a `.json` file directly from the browser.

Data stays local to the user's device/browser unless they manually export and share a file.

## Deploy to GitHub Pages

This repository includes a GitHub Actions workflow at `.github/workflows/deploy-github-pages.yml`.

1. Create a GitHub repository for this project.
2. Commit and push the app to the repository's `main` branch.
3. In GitHub, open the repository settings.
4. Go to **Pages**.
5. Under **Build and deployment**, set **Source** to **GitHub Actions**.
6. Push to `main` or run the workflow manually from the **Actions** tab.

The workflow runs:

```sh
flutter build web --release --base-href "/${{ github.event.repository.name }}/"
```

That base href is correct for a repository GitHub Pages URL such as:

```text
https://your-username.github.io/protocolflow/
```

## Change the Base Href

For repository-based GitHub Pages, the base href must match the repository name and include leading and trailing slashes:

```sh
flutter build web --release --base-href /your-repository-name/
```

The workflow already uses the GitHub repository name automatically:

```yaml
flutter build web --release --base-href "/${{ github.event.repository.name }}/"
```

If you publish to a user or organization site at the root, such as `https://your-username.github.io/`, change the workflow build command to:

```sh
flutter build web --release --base-href /
```

If you rename the GitHub repository, the current workflow does not need to be edited because it reads the repository name from GitHub Actions.
