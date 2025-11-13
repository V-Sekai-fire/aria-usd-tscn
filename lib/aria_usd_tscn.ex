# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

defmodule AriaUsdTscn do
  @moduledoc """
  USD to TSCN and TSCN to USD conversion operations.
  """

  alias AriaUsd
  alias Pythonx
  alias Jason

  @type usd_result :: {:ok, term()} | {:error, String.t()}

  @doc """
  Converts USD to Godot TSCN. TSCN is Godot's internal format, but USD ↔ TSCN conversion has loss due to different scene graph representations.

  ## Parameters
    - usd_path: Path to USD file
    - output_tscn_path: Path to output TSCN file

  ## Returns
    - `{:ok, String.t()}` - Success message
    - `{:error, String.t()}` - Error message
  """
  @spec usd_to_tscn(String.t(), String.t()) :: usd_result()
  def usd_to_tscn(usd_path, output_tscn_path)
      when is_binary(usd_path) and is_binary(output_tscn_path) do
    case AriaUsd.ensure_pythonx() do
      :ok -> do_usd_to_tscn(usd_path, output_tscn_path)
      :mock -> mock_usd_to_tscn(usd_path, output_tscn_path)
    end
  end

  defp mock_usd_to_tscn(usd_path, output_tscn_path) do
    # Check if USD file exists
    if File.exists?(usd_path) do
      {:ok, "Mock converted USD #{usd_path} to TSCN #{output_tscn_path}"}
    else
      {:error, "USD file not found: #{usd_path}"}
    end
  end

  defp do_usd_to_tscn(usd_path, output_tscn_path) do
    code = """
    import os
    from pxr import Usd

    usd_path = '#{usd_path}'
    output_tscn_path = '#{output_tscn_path}'

    if not os.path.exists(usd_path):
        raise FileNotFoundError(f"USD file not found: {usd_path}")

    # Open USD stage
    stage = Usd.Stage.Open(usd_path)
    if not stage:
        raise ValueError("Failed to open USD stage")

    # Convert USD to TSCN format
    # TSCN is Godot's text scene format - we'll generate it from USD prims
    tscn_lines = ['[gd_scene load_steps=2 format=3]', '', '[ext_resource type="Script" path="res://script.gd" id=1]', '']

    def traverse_prim(prim, indent=0):
        lines = []
        prefix = '  ' * indent
        prim_path = str(prim.GetPath())
        prim_type = prim.GetTypeName()
        
        # Convert USD prim to TSCN node
        lines.append(f"{prefix}[node name=\\"{prim_path.split('/')[-1]}\\" type=\\"{prim_type}\\" parent=\\"{prim_path}\\" index=0]")
        
        # Add attributes as properties
        for attr in prim.GetAttributes():
            attr_name = str(attr.GetName())
            attr_value = attr.Get()
            lines.append(f"{prefix}{attr_name} = {attr_value}")
        
        # Recurse children
        for child in prim.GetChildren():
            lines.extend(traverse_prim(child, indent + 1))
        
        return lines

    root = stage.GetPseudoRoot()
    for child in root.GetChildren():
        tscn_lines.extend(traverse_prim(child))

    # Write TSCN file
    with open(output_tscn_path, 'w') as f:
        f.write('\\n'.join(tscn_lines))

    result = f"Converted USD {usd_path} to TSCN {output_tscn_path}"
    result
    """

    case Pythonx.eval(code, %{}) do
      {result, _globals} ->
        case Pythonx.decode(result) do
          status when is_binary(status) -> {:ok, status}
          _ -> {:error, "Failed to decode usd_to_tscn result"}
        end

      error ->
        {:error, inspect(error)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Converts Godot TSCN to USD. TSCN is Godot's internal format, but USD ↔ TSCN conversion has loss due to different scene graph representations.

  ## Parameters
    - tscn_path: Path to TSCN file
    - output_usd_path: Path to output USD file
    - opts: Optional keyword list with :tscn_data for pre-parsed TSCN data

  ## Returns
    - `{:ok, String.t()}` - Success message
    - `{:error, String.t()}` - Error message
  """
  @spec tscn_to_usd(String.t(), String.t(), keyword()) :: usd_result()
  def tscn_to_usd(tscn_path, output_usd_path, opts \\ [])
      when is_binary(tscn_path) and is_binary(output_usd_path) do
    tscn_data = Keyword.get(opts, :tscn_data)

    if tscn_data do
      # Use provided parsed TSCN data
      case AriaUsd.ensure_pythonx() do
        :ok -> do_tscn_to_usd_from_parsed(tscn_data, output_usd_path)
        :mock -> mock_tscn_to_usd(tscn_path, output_usd_path)
      end
    else
      # Fallback - would need TSCN parser (not included in standalone module)
      {:error, "TSCN parsing not available in standalone module. Provide :tscn_data option."}
    end
  end

  defp mock_tscn_to_usd(tscn_path, output_usd_path) do
    # Check if TSCN file exists
    if File.exists?(tscn_path) do
      {:ok, "Mock converted TSCN #{tscn_path} to USD #{output_usd_path}"}
    else
      {:error, "TSCN file not found: #{tscn_path}"}
    end
  end

  defp do_tscn_to_usd_from_parsed(tscn_data, output_usd_path) do
    # Encode TSCN data as JSON for Python processing
    tscn_json = Jason.encode!(tscn_data)

    code = """
    import os
    import json
    from pxr import Usd, Gf

    output_usd_path = '#{output_usd_path}'
    tscn_data = json.loads('''#{tscn_json}''')

    # Create USD stage
    stage = Usd.Stage.CreateNew(output_usd_path)

    # Process nodes and build hierarchy
    nodes = tscn_data.get('nodes', [])
    node_map = {}

    # First pass: create all prims
    for node in nodes:
        node_name = node.get('name', 'Node')
        node_type = node.get('type', 'Node')
        parent = node.get('parent')
        
        if parent and parent != ".":
            # Has parent - find parent path
            parent_path = node_map.get(parent, "/")
            prim_path = f"{parent_path}/{node_name}" if parent_path != "/" else f"/{node_name}"
        else:
            # Root node
            prim_path = f"/{node_name}"
        
        prim = stage.DefinePrim(prim_path, node_type)
        node_map[node_name] = prim_path
        
        # Add properties
        properties = node.get('properties', {})
        for prop_name, prop_value in properties.items():
            # Convert property value to USD attribute
            if isinstance(prop_value, dict):
                if prop_value.get('type') == 'Vector3':
                    vec = Gf.Vec3f(prop_value.get('x', 0), prop_value.get('y', 0), prop_value.get('z', 0))
                    attr = prim.CreateAttribute(prop_name, Usd.TypeId.Tokens.Vector3f)
                    attr.Set(vec)
                elif prop_value.get('type') == 'Transform':
                    origin = prop_value.get('origin', {})
                    if isinstance(origin, dict):
                        origin_vec = Gf.Vec3f(origin.get('x', 0), origin.get('y', 0), origin.get('z', 0))
                        transform = Gf.Matrix4d(1.0).SetTranslate(origin_vec)
                        attr = prim.CreateAttribute(prop_name, Usd.TypeId.Tokens.Matrix4d)
                        attr.Set(transform)
            elif isinstance(prop_value, (int, float)):
                attr = prim.CreateAttribute(prop_name, Usd.TypeId.Tokens.Float)
                attr.Set(float(prop_value))
            elif isinstance(prop_value, str):
                attr = prim.CreateAttribute(prop_name, Usd.TypeId.Tokens.String)
                attr.Set(prop_value)
            elif isinstance(prop_value, bool):
                attr = prim.CreateAttribute(prop_name, Usd.TypeId.Tokens.Bool)
                attr.Set(prop_value)

    stage.GetRootLayer().Save()
    result = f"Converted TSCN to USD {output_usd_path} with {len(nodes)} nodes"
    result
    """

    case Pythonx.eval(code, %{}) do
      {result, _globals} ->
        case Pythonx.decode(result) do
          status when is_binary(status) -> {:ok, status}
          _ -> {:error, "Failed to decode tscn_to_usd result"}
        end

      error ->
        {:error, inspect(error)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end
end

