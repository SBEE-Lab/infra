# Small constructors for the panels the overview, audit, and edge dashboards share.
# Older dashboards still spell their panels out in full.
{ datasources }:
let
  inherit (datasources) prometheus loki;

  sourceOf = ds: if ds == "loki" then loki else prometheus;

  mkTarget =
    ds:
    {
      expr,
      legend ? null,
      instant ? false,
      refId ? "A",
    }:
    {
      inherit refId expr;
      datasource = sourceOf ds;
    }
    // (if legend == null then { } else { legendFormat = legend; })
    // (
      if !instant then
        { }
      else if ds == "loki" then
        {
          queryType = "instant";
          instant = true;
        }
      else
        {
          instant = true;
          range = false;
          format = "table";
        }
    );

  withRefIds =
    targets:
    builtins.genList (
      i:
      (builtins.elemAt targets i)
      // {
        refId = builtins.elemAt [ "A" "B" "C" "D" "E" "F" ] i;
      }
    ) (builtins.length targets);

  base =
    {
      id,
      title,
      type,
      ds,
      pos,
      description ? null,
    }:
    {
      inherit id title type;
      datasource = sourceOf ds;
      gridPos = pos;
    }
    // (if description == null then { } else { inherit description; });
in
rec {
  grid = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  steps = list: {
    mode = "absolute";
    steps = map (step: {
      color = builtins.elemAt step 0;
      value = builtins.elemAt step 1;
    }) list;
  };

  # 0 is good, anything above is a finding.
  zeroIsGood = steps [
    [
      "green"
      null
    ]
    [
      "red"
      1
    ]
  ];

  row =
    {
      id,
      title,
      y,
      collapsed ? false,
      panels ? [ ],
    }:
    {
      inherit
        id
        title
        collapsed
        panels
        ;
      type = "row";
      gridPos = grid 0 y 24 1;
    };

  stat =
    {
      id,
      title,
      ds,
      expr,
      pos,
      description ? null,
      unit ? null,
      thresholds ? zeroIsGood,
      noValue ? "0",
      calc ? "lastNotNull",
    }:
    base {
      inherit
        id
        title
        ds
        pos
        description
        ;
      type = "stat";
    }
    // {
      options = {
        colorMode = "background";
        graphMode = "none";
        textMode = "value";
        reduceOptions = {
          calcs = [ calc ];
          fields = "";
          values = false;
        };
      };
      fieldConfig = {
        defaults = {
          inherit thresholds noValue;
        }
        // (if unit == null then { } else { inherit unit; });
        overrides = [ ];
      };
      targets = [
        (mkTarget ds {
          inherit expr;
          instant = true;
        })
      ];
    };

  table =
    {
      id,
      title,
      ds,
      expr,
      pos,
      description ? null,
      hide ? [ ],
      rename ? { },
      sortBy ? null,
      overrides ? [ ],
    }:
    base {
      inherit
        id
        title
        ds
        pos
        description
        ;
      type = "table";
    }
    // {
      options = {
        showHeader = true;
        footer.show = false;
      }
      // (
        if sortBy == null then
          { }
        else
          {
            sortBy = [
              {
                displayName = sortBy;
                desc = true;
              }
            ];
          }
      );
      fieldConfig = {
        defaults = { };
        inherit overrides;
      };
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName = builtins.listToAttrs (
              map
                (name: {
                  inherit name;
                  value = true;
                })
                (
                  [
                    "Time"
                    "__name__"
                  ]
                  ++ hide
                )
            );
            renameByName = rename;
          };
        }
      ];
      targets = [
        (mkTarget ds {
          inherit expr;
          instant = true;
        })
      ];
    };

  timeseries =
    {
      id,
      title,
      ds,
      targets,
      pos,
      description ? null,
      unit ? null,
      stack ? false,
      bars ? false,
    }:
    base {
      inherit
        id
        title
        ds
        pos
        description
        ;
      type = "timeseries";
    }
    // {
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
        };
        tooltip.mode = "multi";
      };
      fieldConfig = {
        defaults = {
          custom = {
            drawStyle = if bars then "bars" else "line";
            fillOpacity = if bars || stack then 60 else 10;
            stacking.mode = if stack then "normal" else "none";
          };
        }
        // (if unit == null then { } else { inherit unit; });
        overrides = [ ];
      };
      targets = withRefIds (map (mkTarget ds) targets);
    };

  logs =
    {
      id,
      title,
      expr,
      pos,
      description ? null,
    }:
    base {
      inherit
        id
        title
        pos
        description
        ;
      type = "logs";
      ds = "loki";
    }
    // {
      options = {
        showTime = true;
        wrapLogMessage = true;
        sortOrder = "Descending";
        enableLogDetails = true;
      };
      targets = [ (mkTarget "loki" { inherit expr; }) ];
    };
}
