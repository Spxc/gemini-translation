# Gemini i18n Translator

This GitHub Action automatically translates i18n JSON files using Google Gemini and opens a Pull Request with the results.

---

## Features

* Uses Google Gemini models for high-quality translations.
* Automatically detects changes and creates a dedicated branch.
* Opens a Pull Request with the translated content.
* Supports custom source paths and output directories via a bash-driven composite action.

---

## Configuration

### Prerequisites

1.  **Gemini API Key**: Obtain an API key from Google AI Studio.
2.  **Repository Permissions**: This action creates branches and Pull Requests. You must grant the workflow write permissions in your workflow file.

### Inputs

| Input | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `gemini_api_key` | Your Google Gemini API Key. | Yes | N/A |
| `source_path` | Path to the source JSON file to be translated. | Yes | N/A |
| `output_dir` | Directory where the translated files should be saved. | Yes | N/A |
| `model` | The Gemini model identifier to use. | No | `gemini-3-flash-preview` |

---

## Supported Models
| Model | Supported | Stable |
| :--- | :--- | :--- |
| `gemini-2-flash` | Yes | Yes |
| `gemini-3-flash` | Yes | Yes |
| `gemini-3-flash-preview` | Yes | No |
| `gemini-3-flash-thinking-exp` | Yes | No |

---

## Usage Example

Create a file named `.github/workflows/translate.yml` in your repository:

```yaml
name: Auto Translation

on:
  push:
    branches:
      - main
    paths:
      - 'locales/en.json'

jobs:
  translate:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Gemini Translator
        uses: spxc/gemini-translation@v1
        with:
          gemini_api_key: ${{ secrets.GEMINI_API_KEY }}
          source_path: 'locales/en.json'
          output_dir: 'locales'
          model: 'gemini-3-flash-preview'
