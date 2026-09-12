# Moved to `actions@austenstone`

The canonical home for this project is now [`austenstone/.copilot/plugins/actions`](https://github.com/austenstone/.copilot/tree/main/plugins/actions).

Install it with [GitHub Copilot CLI plugins](https://docs.github.com/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing):

```bash
copilot plugin marketplace add austenstone/.copilot
copilot plugin install actions@austenstone
```

The plugin is a self-contained [Agent Plugins 1.0](https://agent-plugins.org/) package containing:

- `actions-workflow-toolkit`
- `actions-optimization`
- `actions-security-review`
- `actions-architecture-review`

For non-Copilot or other compatible clients, consume the self-contained [`plugins/actions`](https://github.com/austenstone/.copilot/tree/main/plugins/actions) Agent Plugins 1.0 directory or the individual skill directories within it using that client's documented installation mechanism. Compatibility beyond the validated Copilot CLI flow is not claimed here.

This repository remains as a relocation notice and retains its MIT [LICENSE](LICENSE). Development continues only in the canonical plugin directory.
