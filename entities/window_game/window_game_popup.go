embedded_components {
  id: "collectionproxy"
  type: "collectionproxy"
  data: "collection: \"/entities/window_game/window_game.collection\"\n"
}
components {
  id: "screen"
  component: "/monarch/screen_proxy.script"
  properties {
    id: "screen_id"
    value: "window_game"
    type: PROPERTY_TYPE_HASH
  }
  properties {
    id: "popup"
    value: "true"
    type: PROPERTY_TYPE_BOOLEAN
  }
}
