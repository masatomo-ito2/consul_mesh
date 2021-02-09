service {
  name = "backend",
  id= "backend-v2",
  port = 10002,
  token = "",
  connect {
    sidecar_service {}
  }
  meta {
    version = "v2"
  }
  tags = [ "v2" ]
}
