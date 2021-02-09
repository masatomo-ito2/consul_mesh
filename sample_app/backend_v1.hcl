service {
  name = "backend",
  id= "backend-v1",
  port = 10001,
  token = "",
  connect {
    sidecar_service {}
  }
  meta {
    version = "v1"
  }
  tags = [ "v1" ]
}
