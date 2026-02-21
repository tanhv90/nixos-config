# Overlay to get latest Claude Code version
# Claude Code bundles all deps, so npmDepsHash can be empty
_: _final: prev: {
  claude-code = prev.claude-code.overrideAttrs (_oldAttrs: rec {
    version = "2.1.39";
    src = prev.fetchurl {
      url = "https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-${version}.tgz";
      hash = "sha256-iJB/LuXYACOu6Y5czpP7eGFdrvZTbVUeK7K8pBmjxvY=";
    };
    npmDepsHash = "";
  });
}
