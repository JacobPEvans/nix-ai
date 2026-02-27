# Gemini Custom Commands Adapter
#
# Automatically generates Gemini CLI custom commands from shared Markdown definitions.
# Reads from ai-assistant-instructions/agentsmd/commands/*.md
# Returns home.file entries for ~/.gemini/commands/*.toml
#
# This allows maintaining a single source of truth in agentsmd for both Claude and Gemini.

{ lib, ai-assistant-instructions, ... }:

let
  # Path to shared commands directory in the flake input
  commandsDir = "${ai-assistant-instructions}/agentsmd/commands";

  # Helper to process a single Markdown command file into a Gemini TOML file
  processCommandFile =
    fileName:
    let
      filePath = "${commandsDir}/${fileName}";
      fileContent = builtins.readFile filePath;

      # Robust frontmatter/content splitter
      # Assumes standard Jekyll/Claude style frontmatter at top of file:
      # ---
      # key: value
      # ---
      # Content...
      lines = lib.splitString "\n" fileContent;
      lineCount = builtins.length lines;

      # Find the index of the second frontmatter delimiter ("---"), starting at line 1
      secondDelimIndex =
        let
          find =
            idx:
            if idx >= lineCount then
              null
            else if lib.trim (builtins.elemAt lines idx) == "---" then
              idx
            else
              find (idx + 1);
        in
        find 1;

      # Valid frontmatter exists only if the file starts with "---" and we find a second delimiter
      hasFrontmatter =
        lineCount >= 3 && lib.trim (builtins.elemAt lines 0) == "---" && secondDelimIndex != null;

      frontmatterRaw =
        if hasFrontmatter then
          let
            frontmatterLines = lib.sublist 1 (secondDelimIndex - 1) lines;
          in
          lib.concatStringsSep "\n" frontmatterLines
        else
          "";

      contentRaw =
        if hasFrontmatter then
          let
            contentLines = lib.sublist (secondDelimIndex + 1) (lineCount - secondDelimIndex - 1) lines;
          in
          lib.concatStringsSep "\n" contentLines
        else
          fileContent;

      # Extract description from frontmatter
      # Looks for "description: text" line
      descLine = lib.findFirst (l: lib.hasPrefix "description:" (lib.trim l)) null (
        lib.splitString "\n" frontmatterRaw
      );

      description =
        if descLine != null then
          lib.trim (lib.removePrefix "description:" (lib.trim descLine))
        else
          "Custom command generated from ${fileName}";

      # Generate Gemini TOML format
      # We use multi-line string for the command content
      # NOTE: We escape backslashes and double quotes in description
      safeDescription = lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] description;

      # Escape triple quotes in content to prevent TOML parsing errors
      # TOML multi-line strings (""") break if content contains """
      safeContent = lib.replaceStrings [ "\"\"\"" ] [ "\"\"\\\"" ] (lib.trim contentRaw);

      tomlContent = ''
        description = "${safeDescription}"
        prompt = """
        ${safeContent}
        """
      '';

      # Output filename: replace .md extension with .toml
      outName = lib.replaceStrings [ ".md" ] [ ".toml" ] fileName;
    in
    {
      name = ".gemini/commands/${outName}";
      value = {
        text = tomlContent;
        force = true;
      };
    };

  # Filter for Markdown files in the commands directory
  commandFiles =
    if builtins.pathExists commandsDir then
      builtins.attrNames (
        lib.filterAttrs (n: v: v == "regular" && lib.hasSuffix ".md" n) (builtins.readDir commandsDir)
      )
    else
      [ ];

in
# Return an attribute set of home.file entries
builtins.listToAttrs (map processCommandFile commandFiles)
