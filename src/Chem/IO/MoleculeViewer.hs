{-# LANGUAGE OverloadedStrings #-}

module Chem.IO.MoleculeViewer
  ( moleculeViewerPayload
  , moleculeViewerHTML
  , writeMoleculeViewerHTML
  , openMoleculeViewer
  ) where

import           Control.Exception (SomeException, try)
import qualified Data.Aeson as A
import           Data.Aeson ((.=))
import qualified Data.ByteString.Lazy.Char8 as BL8
import qualified Data.Map.Strict as M
import qualified Data.Set as S
import qualified Data.Text as T
import           System.Directory (createDirectoryIfMissing)
import           System.FilePath (takeDirectory)
import           System.Info (os)
import           System.Process (callProcess)

import           Chem.Dietz
import           Chem.Molecule

moleculeViewerPayload :: String -> Molecule -> A.Value
moleculeViewerPayload title molecule =
  A.object
    [ "format" .= ("moladt-viewer-v1" :: T.Text)
    , "title" .= T.pack title
    , "atoms" .= map atomPayload (M.toAscList (atoms molecule))
    , "bonds" .= map bondPayload (S.toAscList allEdges)
    , "systems" .= zipWith systemPayload [0 :: Int ..] (systems molecule)
    ]
  where
    allEdges =
      S.unions (localBonds molecule : map (memberEdges . snd) (systems molecule))

    atomPayload :: (AtomId, Atom) -> A.Value
    atomPayload (AtomId rawId, atom) =
      A.object
        [ "id" .= rawId
        , "symbol" .= T.pack (show atomSymbol)
        , "label" .= T.pack (show atomSymbol ++ show rawId)
        , "x" .= unAngstrom x
        , "y" .= unAngstrom y
        , "z" .= unAngstrom z
        , "charge" .= formalCharge atom
        , "color" .= T.pack fill
        , "edge" .= T.pack stroke
        , "radius" .= radius
        ]
      where
        atomSymbol = symbol (attributes atom)
        Coordinate x y z = coordinate atom
        (fill, stroke, radius) = elementStyle atomSymbol

    bondPayload :: Edge -> A.Value
    bondPayload edge@(Edge (AtomId atomA) (AtomId atomB)) =
      A.object
        [ "a" .= atomA
        , "b" .= atomB
        , "order" .= effectiveOrder molecule edge
        , "kind" .= edgeKind
        ]
      where
        edgeKind :: T.Text
        edgeKind =
          if edge `S.member` localBonds molecule
            then "sigma"
            else "system"

    systemPayload :: Int -> (SystemId, BondingSystem) -> A.Value
    systemPayload index (SystemId rawId, bondingSystem) =
      A.object
        [ "id" .= rawId
        , "label" .= T.pack labelText
        , "tag" .= fmap T.pack (tag bondingSystem)
        , "sharedElectrons" .= getNN (sharedElectrons bondingSystem)
        , "color" .= T.pack (systemColor index)
        , "atoms" .= map atomIdValue (S.toAscList (memberAtoms bondingSystem))
        , "edges" .= map systemEdgePayload (S.toAscList (memberEdges bondingSystem))
        ]
      where
        labelText = maybe ("system " ++ show rawId) id (tag bondingSystem)

    atomIdValue :: AtomId -> Integer
    atomIdValue (AtomId rawId) = rawId

    systemEdgePayload :: Edge -> A.Value
    systemEdgePayload (Edge (AtomId atomA) (AtomId atomB)) =
      A.object ["a" .= atomA, "b" .= atomB]

moleculeViewerHTML :: String -> Molecule -> String
moleculeViewerHTML title molecule =
  unlines $
    [ "<!doctype html>"
    , "<html lang=\"en\">"
    , "<head>"
    , "<meta charset=\"utf-8\">"
    , "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    , "<title>" ++ safeTitle ++ "</title>"
    , "<style>"
    , ":root {"
    , "  color-scheme: light;"
    , "  --ink: #111827;"
    , "  --muted: #667085;"
    , "  --line: #d7dce3;"
    , "  --panel: rgba(255, 255, 255, 0.86);"
    , "  --surface: #f7f8fb;"
    , "  --accent: #0f766e;"
    , "}"
    , "* { box-sizing: border-box; }"
    , "html, body { height: 100%; }"
    , "body {"
    , "  margin: 0;"
    , "  min-height: 100%;"
    , "  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;"
    , "  color: var(--ink);"
    , "  background: linear-gradient(180deg, #fbfcfd 0%, #eef2f6 100%);"
    , "}"
    , ".shell {"
    , "  min-height: 100vh;"
    , "  display: grid;"
    , "  grid-template-columns: minmax(280px, 360px) minmax(0, 1fr);"
    , "  gap: 18px;"
    , "  padding: 18px;"
    , "}"
    , ".side, .stage {"
    , "  border: 1px solid var(--line);"
    , "  background: var(--panel);"
    , "  backdrop-filter: blur(18px);"
    , "  box-shadow: 0 22px 70px rgba(15, 23, 42, 0.10);"
    , "}"
    , ".side {"
    , "  border-radius: 8px;"
    , "  display: flex;"
    , "  flex-direction: column;"
    , "  min-height: calc(100vh - 36px);"
    , "  overflow: hidden;"
    , "}"
    , ".titlebar { padding: 20px 20px 14px; border-bottom: 1px solid var(--line); }"
    , "h1 { margin: 0; font-size: 24px; line-height: 1.08; letter-spacing: 0; }"
    , ".counts { margin-top: 8px; color: var(--muted); font-size: 13px; line-height: 1.4; }"
    , ".controls { padding: 16px 20px; display: grid; gap: 14px; border-bottom: 1px solid var(--line); }"
    , ".control-row { display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 13px; color: #344054; }"
    , ".control-row input[type='checkbox'] { width: 18px; height: 18px; accent-color: var(--accent); }"
    , ".control-row input[type='range'] { width: 140px; accent-color: var(--accent); }"
    , ".dropzone {"
    , "  margin: 16px 20px 0;"
    , "  min-height: 52px;"
    , "  border: 1px dashed #b7c0cb;"
    , "  border-radius: 8px;"
    , "  display: grid;"
    , "  place-items: center;"
    , "  color: var(--muted);"
    , "  font-size: 13px;"
    , "  background: rgba(255, 255, 255, 0.58);"
    , "}"
    , ".dropzone.active { border-color: var(--accent); color: var(--accent); background: rgba(15, 118, 110, 0.08); }"
    , ".system-list { padding: 16px 20px 20px; display: grid; gap: 10px; overflow: auto; }"
    , ".system-button {"
    , "  appearance: none;"
    , "  border: 1px solid var(--line);"
    , "  background: rgba(255, 255, 255, 0.72);"
    , "  color: #1f2937;"
    , "  border-radius: 8px;"
    , "  min-height: 52px;"
    , "  padding: 10px 12px;"
    , "  display: grid;"
    , "  grid-template-columns: 14px 1fr auto;"
    , "  align-items: center;"
    , "  gap: 10px;"
    , "  text-align: left;"
    , "  cursor: pointer;"
    , "}"
    , ".system-button[aria-pressed='true'] { border-color: rgba(15, 118, 110, 0.42); background: rgba(15, 118, 110, 0.07); }"
    , ".swatch { width: 12px; height: 12px; border-radius: 999px; box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.12); }"
    , ".system-name { overflow-wrap: anywhere; font-size: 13px; font-weight: 650; }"
    , ".system-meta { color: var(--muted); font-size: 12px; white-space: nowrap; }"
    , ".stage {"
    , "  position: relative;"
    , "  border-radius: 8px;"
    , "  overflow: hidden;"
    , "  min-height: calc(100vh - 36px);"
    , "  background: radial-gradient(circle at 50% 44%, #ffffff 0%, var(--surface) 54%, #e7edf3 100%);"
    , "}"
    , "#molecule-canvas { width: 100%; height: 100%; display: block; touch-action: none; cursor: grab; }"
    , "#molecule-canvas.dragging { cursor: grabbing; }"
    , ".badge {"
    , "  position: absolute;"
    , "  right: 16px;"
    , "  bottom: 16px;"
    , "  color: var(--muted);"
    , "  font-size: 12px;"
    , "  background: rgba(255, 255, 255, 0.76);"
    , "  border: 1px solid var(--line);"
    , "  border-radius: 999px;"
    , "  padding: 7px 10px;"
    , "}"
    , "@media (max-width: 860px) {"
    , "  .shell { grid-template-columns: 1fr; padding: 12px; }"
    , "  .side { min-height: auto; }"
    , "  .stage { min-height: 68vh; }"
    , "  .system-list { max-height: 220px; }"
    , "}"
    , "</style>"
    , "</head>"
    , "<body data-moladt-viewer>"
    , "<main class=\"shell\">"
    , "  <aside class=\"side\">"
    , "    <div class=\"titlebar\">"
    , "      <h1 id=\"viewer-title\">" ++ safeTitle ++ "</h1>"
    , "      <div id=\"counts\" class=\"counts\"></div>"
    , "    </div>"
    , "    <div class=\"controls\">"
    , "      <label class=\"control-row\"><span>Labels</span><input id=\"labels-toggle\" type=\"checkbox\" checked></label>"
    , "      <label class=\"control-row\"><span>Bonding systems</span><input id=\"systems-toggle\" type=\"checkbox\" checked></label>"
    , "      <label class=\"control-row\"><span>Zoom</span><input id=\"zoom-range\" type=\"range\" min=\"70\" max=\"190\" value=\"110\"></label>"
    , "    </div>"
    , "    <div id=\"dropzone\" class=\"dropzone\">Drop MolADT JSON</div>"
    , "    <div id=\"system-list\" class=\"system-list\"></div>"
    , "  </aside>"
    , "  <section class=\"stage\">"
    , "    <canvas id=\"molecule-canvas\" aria-label=\"MolADT molecule viewer\"></canvas>"
    , "    <div class=\"badge\">MolADT viewer</div>"
    , "  </section>"
    , "</main>"
    , "<script id=\"moladt-payload\" type=\"application/json\">" ++ payloadJson ++ "</script>"
    , "<script>"
    , "(function () {"
    , "  const canvas = document.getElementById('molecule-canvas');"
    , "  const ctx = canvas.getContext('2d');"
    , "  const titleNode = document.getElementById('viewer-title');"
    , "  const countsNode = document.getElementById('counts');"
    , "  const systemList = document.getElementById('system-list');"
    , "  const labelsToggle = document.getElementById('labels-toggle');"
    , "  const systemsToggle = document.getElementById('systems-toggle');"
    , "  const zoomRange = document.getElementById('zoom-range');"
    , "  const dropZone = document.getElementById('dropzone');"
    , "  const state = {"
    , "    payload: null,"
    , "    rotationX: -0.58,"
    , "    rotationY: 0.72,"
    , "    zoom: 1.1,"
    , "    labels: true,"
    , "    systems: true,"
    , "    selectedSystem: null,"
    , "    dragging: false,"
    , "    lastX: 0,"
    , "    lastY: 0"
    , "  };"
    , "  const systemColors = ['#0f766e', '#b45309', '#2563eb', '#be185d', '#7c3aed', '#15803d', '#c2410c', '#475569'];"
    , "  function edgeKey(a, b) { return Number(a) <= Number(b) ? `${a}-${b}` : `${b}-${a}`; }"
    , "  function idValue(value) {"
    , "    if (value && typeof value === 'object' && Object.prototype.hasOwnProperty.call(value, 'value')) return Number(value.value);"
    , "    return Number(value);"
    , "  }"
    , "  function coordValue(value) {"
    , "    if (value && typeof value === 'object' && Object.prototype.hasOwnProperty.call(value, 'value')) return Number(value.value);"
    , "    return Number(value || 0);"
    , "  }"
    , "  function styleFor(symbol) {"
    , "    const table = {"
    , "      H: ['#f8fafc', '#9aa6b2', 0.31], C: ['#303640', '#12151a', 0.76], N: ['#3d6fd8', '#244998', 0.71],"
    , "      O: ['#d94a42', '#9e2722', 0.66], F: ['#3aa66a', '#247143', 0.57], Cl: ['#79b84a', '#4a7d27', 1.02],"
    , "      Br: ['#a85d35', '#73391f', 1.2], I: ['#7d4fa3', '#53306f', 1.39], B: ['#f0a46d', '#b76b35', 0.84],"
    , "      S: ['#e1ba2f', '#9a7c18', 1.05], P: ['#d67f30', '#96541a', 1.07], Si: ['#9c7fbd', '#69528b', 1.11],"
    , "      Fe: ['#d27845', '#944521', 1.32], Na: ['#7b8de8', '#4d5ca8', 1.66]"
    , "    };"
    , "    return table[symbol] || ['#7b8794', '#485260', 0.82];"
    , "  }"
    , "  function normaliseRawMolADT(raw) {"
    , "    const atoms = (raw.atoms || []).map(function (entry) {"
    , "      const atom = entry.atom || entry;"
    , "      const id = idValue(entry.atom_id || atom.atom_id || atom.id);"
    , "      const attrs = atom.attributes || {};"
    , "      const symbol = attrs.symbol || atom.symbol || 'C';"
    , "      const coord = atom.coordinate || {};"
    , "      const style = styleFor(symbol);"
    , "      return {"
    , "        id: id,"
    , "        symbol: symbol,"
    , "        label: `${symbol}${id}`,"
    , "        x: coordValue(coord.x),"
    , "        y: coordValue(coord.y),"
    , "        z: coordValue(coord.z),"
    , "        charge: Number(atom.formal_charge || atom.charge || 0),"
    , "        color: style[0],"
    , "        edge: style[1],"
    , "        radius: style[2]"
    , "      };"
    , "    });"
    , "    const bondsByKey = new Map();"
    , "    (raw.local_bonds || raw.bonds || []).forEach(function (edge) {"
    , "      const a = idValue(edge.a);"
    , "      const b = idValue(edge.b);"
    , "      bondsByKey.set(edgeKey(a, b), { a: a, b: b, order: Number(edge.order || 1), kind: edge.kind || 'sigma' });"
    , "    });"
    , "    const systems = (raw.systems || []).map(function (entry, index) {"
    , "      const system = entry.bonding_system || entry;"
    , "      const id = idValue(entry.system_id || system.id || index + 1);"
    , "      const edges = (system.member_edges || system.edges || []).map(function (edge) {"
    , "        const a = idValue(edge.a);"
    , "        const b = idValue(edge.b);"
    , "        if (!bondsByKey.has(edgeKey(a, b))) bondsByKey.set(edgeKey(a, b), { a: a, b: b, order: 0, kind: 'system' });"
    , "        return { a: a, b: b };"
    , "      });"
    , "      const tag = system.tag || null;"
    , "      const shared = system.shared_electrons || system.sharedElectrons || { value: 0 };"
    , "      return {"
    , "        id: id,"
    , "        label: tag || `system ${id}` ,"
    , "        tag: tag,"
    , "        sharedElectrons: idValue(shared),"
    , "        color: system.color || systemColors[index % systemColors.length],"
    , "        atoms: (system.member_atoms || system.atoms || []).map(idValue),"
    , "        edges: edges"
    , "      };"
    , "    });"
    , "    return {"
    , "      format: 'moladt-viewer-v1',"
    , "      title: raw.title || 'MolADT viewer',"
    , "      atoms: atoms,"
    , "      bonds: Array.from(bondsByKey.values()),"
    , "      systems: systems"
    , "    };"
    , "  }"
    , "  function normalisePayload(raw) {"
    , "    if (raw && raw.format === 'moladt-viewer-v1') return raw;"
    , "    return normaliseRawMolADT(raw || {});"
    , "  }"
    , "  function systemEdgeLaneMap(systems) {"
    , "    const lanes = new Map();"
    , "    systems.forEach(function (system) {"
    , "      system.edges.forEach(function (edge) {"
    , "        const key = edgeKey(edge.a, edge.b);"
    , "        const existing = lanes.get(key) || [];"
    , "        existing.push(system.id);"
    , "        lanes.set(key, existing);"
    , "      });"
    , "    });"
    , "    return lanes;"
    , "  }"
    , "  function bounds(atoms) {"
    , "    if (!atoms.length) return { center: { x: 0, y: 0, z: 0 }, span: 1 };"
    , "    const xs = atoms.map((atom) => atom.x);"
    , "    const ys = atoms.map((atom) => atom.y);"
    , "    const zs = atoms.map((atom) => atom.z);"
    , "    const minX = Math.min.apply(null, xs); const maxX = Math.max.apply(null, xs);"
    , "    const minY = Math.min.apply(null, ys); const maxY = Math.max.apply(null, ys);"
    , "    const minZ = Math.min.apply(null, zs); const maxZ = Math.max.apply(null, zs);"
    , "    return {"
    , "      center: { x: (minX + maxX) / 2, y: (minY + maxY) / 2, z: (minZ + maxZ) / 2 },"
    , "      span: Math.max(maxX - minX, maxY - minY, maxZ - minZ, 1)"
    , "    };"
    , "  }"
    , "  function project(atom, modelBounds, size) {"
    , "    const x = atom.x - modelBounds.center.x;"
    , "    const y = atom.y - modelBounds.center.y;"
    , "    const z = atom.z - modelBounds.center.z;"
    , "    const cy = Math.cos(state.rotationY);"
    , "    const sy = Math.sin(state.rotationY);"
    , "    const cx = Math.cos(state.rotationX);"
    , "    const sx = Math.sin(state.rotationX);"
    , "    const x1 = x * cy - z * sy;"
    , "    const z1 = x * sy + z * cy;"
    , "    const y2 = y * cx - z1 * sx;"
    , "    const z2 = y * sx + z1 * cx;"
    , "    const scale = Math.min(size.w, size.h) / (modelBounds.span * 2.25);"
    , "    const perspective = 800 / (800 + z2 * 80);"
    , "    return {"
    , "      x: size.w / 2 + x1 * scale * state.zoom * perspective,"
    , "      y: size.h / 2 + y2 * scale * state.zoom * perspective,"
    , "      z: z2,"
    , "      radius: Math.max(6, Math.min(28, atom.radius * scale * 0.22 * state.zoom))"
    , "    };"
    , "  }"
    , "  function drawEdge(a, b, color, options) {"
    , "    if (!a || !b) return;"
    , "    const dx = b.x - a.x;"
    , "    const dy = b.y - a.y;"
    , "    const length = Math.max(1, Math.sqrt(dx * dx + dy * dy));"
    , "    const offset = options.offset || 0;"
    , "    const ox = -dy / length * offset;"
    , "    const oy = dx / length * offset;"
    , "    ctx.save();"
    , "    ctx.globalAlpha = options.alpha == null ? 1 : options.alpha;"
    , "    ctx.lineWidth = options.width || 2;"
    , "    ctx.lineCap = 'round';"
    , "    ctx.strokeStyle = color;"
    , "    if (options.dashed) ctx.setLineDash([7, 8]);"
    , "    ctx.beginPath();"
    , "    ctx.moveTo(a.x + ox, a.y + oy);"
    , "    ctx.lineTo(b.x + ox, b.y + oy);"
    , "    ctx.stroke();"
    , "    ctx.restore();"
    , "  }"
    , "  function render() {"
    , "    const payload = state.payload;"
    , "    if (!payload) return;"
    , "    const size = { w: canvas.clientWidth || 900, h: canvas.clientHeight || 640 };"
    , "    ctx.clearRect(0, 0, size.w, size.h);"
    , "    const modelBounds = bounds(payload.atoms);"
    , "    const projected = new Map();"
    , "    payload.atoms.forEach(function (atom) { projected.set(atom.id, project(atom, modelBounds, size)); });"
    , "    payload.bonds.forEach(function (bond) {"
    , "      const a = projected.get(bond.a);"
    , "      const b = projected.get(bond.b);"
    , "      drawEdge(a, b, bond.kind === 'system' ? '#9aa6b2' : '#8a95a3', { offset: 0, alpha: bond.kind === 'system' ? 0.24 : 0.58, width: Math.max(2, Math.min(5, 1.7 + Number(bond.order || 1))) });"
    , "    });"
    , "    if (state.systems) {"
    , "      const lanes = systemEdgeLaneMap(payload.systems);"
    , "      payload.systems.forEach(function (system) {"
    , "        const active = state.selectedSystem == null || state.selectedSystem === system.id;"
    , "        system.edges.forEach(function (edge) {"
    , "          const laneIds = lanes.get(edgeKey(edge.a, edge.b)) || [system.id];"
    , "          const lane = Math.max(0, laneIds.indexOf(system.id));"
    , "          const laneOffset = (lane - (laneIds.length - 1) / 2) * 7;"
    , "          drawEdge(projected.get(edge.a), projected.get(edge.b), system.color, {"
    , "            offset: laneOffset,"
    , "            alpha: active ? 1 : 0.18,"
    , "            width: active ? 4 : 2"
    , "          });"
    , "        });"
    , "      });"
    , "    }"
    , "    payload.atoms.slice().sort(function (left, right) { return projected.get(left.id).z - projected.get(right.id).z; }).forEach(function (atom) {"
    , "      const point = projected.get(atom.id);"
    , "      const radius = point.radius;"
    , "      ctx.save();"
    , "      ctx.beginPath();"
    , "      ctx.arc(point.x, point.y, radius, 0, Math.PI * 2);"
    , "      ctx.fillStyle = atom.color;"
    , "      ctx.strokeStyle = atom.edge;"
    , "      ctx.lineWidth = 1.5;"
    , "      ctx.shadowColor = 'rgba(15, 23, 42, 0.18)';"
    , "      ctx.shadowBlur = 14;"
    , "      ctx.shadowOffsetY = 5;"
    , "      ctx.fill();"
    , "      ctx.shadowColor = 'transparent';"
    , "      ctx.stroke();"
    , "      if (state.labels) {"
    , "        ctx.font = '12px ui-sans-serif, system-ui, sans-serif';"
    , "        ctx.fillStyle = '#182230';"
    , "        ctx.textAlign = 'center';"
    , "        ctx.textBaseline = 'middle';"
    , "        const label = atom.label || `${atom.symbol}${atom.id}`;"
    , "        ctx.fillText(label, point.x, point.y + radius + 13);"
    , "      }"
    , "      ctx.restore();"
    , "    });"
    , "  }"
    , "  function renderPanel() {"
    , "    const payload = state.payload;"
    , "    if (!payload) return;"
    , "    titleNode.textContent = payload.title || 'MolADT viewer';"
    , "    countsNode.textContent = `${payload.atoms.length} atoms, ${payload.bonds.length} edges, ${payload.systems.length} bonding systems`;"
    , "    systemList.innerHTML = '';"
    , "    if (!payload.systems.length) {"
    , "      const empty = document.createElement('div');"
    , "      empty.className = 'counts';"
    , "      empty.textContent = 'No explicit bonding systems';"
    , "      systemList.appendChild(empty);"
    , "      return;"
    , "    }"
    , "    payload.systems.forEach(function (system) {"
    , "      const button = document.createElement('button');"
    , "      button.type = 'button';"
    , "      button.className = 'system-button';"
    , "      button.setAttribute('aria-pressed', String(state.selectedSystem === system.id));"
    , "      const swatch = document.createElement('span');"
    , "      swatch.className = 'swatch';"
    , "      swatch.style.background = system.color;"
    , "      const name = document.createElement('span');"
    , "      name.className = 'system-name';"
    , "      name.textContent = system.label || `system ${system.id}`;"
    , "      const meta = document.createElement('span');"
    , "      meta.className = 'system-meta';"
    , "      meta.textContent = `${system.sharedElectrons}e, ${system.edges.length} edges`;"
    , "      button.appendChild(swatch);"
    , "      button.appendChild(name);"
    , "      button.appendChild(meta);"
    , "      button.addEventListener('click', function () {"
    , "        state.selectedSystem = state.selectedSystem === system.id ? null : system.id;"
    , "        renderPanel();"
    , "        render();"
    , "      });"
    , "      systemList.appendChild(button);"
    , "    });"
    , "  }"
    , "  function resizeCanvas() {"
    , "    const rect = canvas.getBoundingClientRect();"
    , "    const dpr = window.devicePixelRatio || 1;"
    , "    canvas.width = Math.max(1, Math.floor(rect.width * dpr));"
    , "    canvas.height = Math.max(1, Math.floor(rect.height * dpr));"
    , "    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);"
    , "    render();"
    , "  }"
    , "  window.loadMolADT = function (rawPayload) {"
    , "    state.payload = normalisePayload(rawPayload);"
    , "    state.selectedSystem = null;"
    , "    renderPanel();"
    , "    resizeCanvas();"
    , "  };"
    , "  canvas.addEventListener('pointerdown', function (event) {"
    , "    state.dragging = true;"
    , "    state.lastX = event.clientX;"
    , "    state.lastY = event.clientY;"
    , "    canvas.classList.add('dragging');"
    , "    canvas.setPointerCapture(event.pointerId);"
    , "  });"
    , "  canvas.addEventListener('pointermove', function (event) {"
    , "    if (!state.dragging) return;"
    , "    const dx = event.clientX - state.lastX;"
    , "    const dy = event.clientY - state.lastY;"
    , "    state.rotationY += dx * 0.01;"
    , "    state.rotationX += dy * 0.01;"
    , "    state.lastX = event.clientX;"
    , "    state.lastY = event.clientY;"
    , "    render();"
    , "  });"
    , "  canvas.addEventListener('pointerup', function (event) {"
    , "    state.dragging = false;"
    , "    canvas.classList.remove('dragging');"
    , "    canvas.releasePointerCapture(event.pointerId);"
    , "  });"
    , "  canvas.addEventListener('pointercancel', function () {"
    , "    state.dragging = false;"
    , "    canvas.classList.remove('dragging');"
    , "  });"
    , "  labelsToggle.addEventListener('change', function () { state.labels = labelsToggle.checked; render(); });"
    , "  systemsToggle.addEventListener('change', function () { state.systems = systemsToggle.checked; render(); });"
    , "  zoomRange.addEventListener('input', function () { state.zoom = Number(zoomRange.value) / 100; render(); });"
    , "  ['dragenter', 'dragover'].forEach(function (name) {"
    , "    dropZone.addEventListener(name, function (event) { event.preventDefault(); dropZone.classList.add('active'); });"
    , "  });"
    , "  ['dragleave', 'drop'].forEach(function (name) {"
    , "    dropZone.addEventListener(name, function (event) { event.preventDefault(); dropZone.classList.remove('active'); });"
    , "  });"
    , "  dropZone.addEventListener('drop', function (event) {"
    , "    const file = event.dataTransfer.files && event.dataTransfer.files[0];"
    , "    if (!file) return;"
    , "    file.text().then(function (text) { window.loadMolADT(JSON.parse(text)); }).catch(function (error) {"
    , "      countsNode.textContent = `Could not load JSON: ${error.message}`;"
    , "    });"
    , "  });"
    , "  window.addEventListener('resize', resizeCanvas);"
    , "  const embedded = JSON.parse(document.getElementById('moladt-payload').textContent);"
    , "  window.loadMolADT(embedded);"
    , "}());"
    , "</script>"
    , "</body>"
    , "</html>"
    ]
  where
    safeTitle = escapeHTML title
    payloadJson = escapeJsonForScript (BL8.unpack (A.encode (moleculeViewerPayload title molecule)))

writeMoleculeViewerHTML :: FilePath -> String -> Molecule -> IO FilePath
writeMoleculeViewerHTML path title molecule = do
  createDirectoryIfMissing True (takeDirectory path)
  writeFile path (moleculeViewerHTML title molecule)
  pure path

openMoleculeViewer :: FilePath -> IO Bool
openMoleculeViewer path = do
  result <- try (callProcess opener openerArgs) :: IO (Either SomeException ())
  pure (either (const False) (const True) result)
  where
    (opener, openerArgs) =
      case os of
        "darwin" -> ("open", [path])
        "mingw32" -> ("cmd", ["/c", "start", "", path])
        _ -> ("xdg-open", [path])

elementStyle :: AtomicSymbol -> (String, String, Double)
elementStyle atomSymbol =
  case atomSymbol of
    H -> ("#f8fafc", "#9aa6b2", 0.31)
    C -> ("#303640", "#12151a", 0.76)
    N -> ("#3d6fd8", "#244998", 0.71)
    O -> ("#d94a42", "#9e2722", 0.66)
    F -> ("#3aa66a", "#247143", 0.57)
    Cl -> ("#79b84a", "#4a7d27", 1.02)
    Br -> ("#a85d35", "#73391f", 1.20)
    I -> ("#7d4fa3", "#53306f", 1.39)
    B -> ("#f0a46d", "#b76b35", 0.84)
    S -> ("#e1ba2f", "#9a7c18", 1.05)
    P -> ("#d67f30", "#96541a", 1.07)
    Si -> ("#9c7fbd", "#69528b", 1.11)
    Fe -> ("#d27845", "#944521", 1.32)
    Na -> ("#7b8de8", "#4d5ca8", 1.66)

systemColor :: Int -> String
systemColor index =
  colors !! (index `mod` length colors)
  where
    colors =
      [ "#0f766e"
      , "#b45309"
      , "#2563eb"
      , "#be185d"
      , "#7c3aed"
      , "#15803d"
      , "#c2410c"
      , "#475569"
      ]

escapeHTML :: String -> String
escapeHTML = concatMap escapeChar
  where
    escapeChar char =
      case char of
        '&' -> "&amp;"
        '<' -> "&lt;"
        '>' -> "&gt;"
        '"' -> "&quot;"
        '\'' -> "&#39;"
        _ -> [char]

escapeJsonForScript :: String -> String
escapeJsonForScript = concatMap escapeChar
  where
    escapeChar char =
      case char of
        '<' -> "\\u003c"
        '>' -> "\\u003e"
        '&' -> "\\u0026"
        _ -> [char]
