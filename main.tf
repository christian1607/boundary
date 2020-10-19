provider "boundary" {
  addr                            = "http://127.0.0.1:9200"
  auth_method_id                  = "ampw_1234567890"
  password_auth_method_login_name = "admin"
  password_auth_method_password   = "password"
}

variable "architecture_users" {
  type    = set(string)
  default = [
    "Chirstian",
    "David",
    "Luis"
    
  ]
}

variable "cindi_users" {
  type    = set(string)
  default = [
    "Hernan",
    "Victor"
    
  ]
}


variable "readonly_users" {
  type    = set(string)
  default = [
    "Amadeo",
    "Rolando"
  ]
}

variable "backend_server_ips" {
  type    = set(string)
  default = [
    "10.1.0.1",
    "10.1.0.2",
  ]
}

resource "boundary_scope" "farmaciasperuanas" {
  global_scope = true
  description  = "farmacias peruanas"
  scope_id     = "farmaciasperuanas"

}

resource "boundary_scope" "farmaciasperuanas2" {
  global_scope = true
  description  = "farmacias peruanas2"
  scope_id     = "farmaciasperuanas2"
  
}

resource "boundary_scope" "arquitectura" {
  name                     = "Arquitectura"
  description              = "Arquitectura y Soluciones Digitales"
  scope_id                 = boundary_scope.farmaciasperuanas.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}

resource "boundary_scope" "cindi" {
  name                     = "Cindi"
  description              = "Innovacion y Omnicanalidad"
  scope_id                 = boundary_scope.farmaciasperuanas.id
  auto_create_admin_role   = true
  auto_create_default_role = true
}



## Use password auth method
resource "boundary_auth_method" "arquitectura_password" {
  name     = "Cindi Password method"
  scope_id = boundary_scope.arquitectura.id
  type     = "password"
}

resource "boundary_auth_method" "cindi_password" {
  name     = "Arquitectura Password method"
  scope_id = boundary_scope.cindi.id
  type     = "password"
}


resource "boundary_account" "users_acct" {
  for_each       = var.architecture_users
  name           = each.key
  description    = "User account for ${each.key}"
  type           = "password"
  login_name     = lower(each.key)
  password       = "password"
  auth_method_id = boundary_auth_method.arquitectura_password.id
}



resource "boundary_user" "developers" {
  for_each    = var.architecture_users
  name        = each.key
  description = "User resource for ${each.key}"
  scope_id    = boundary_scope.arquitectura.id
}



resource "boundary_group" "managers" {
  name        = "managers"
  description = "Group Managers"
  member_ids  = [for user in boundary_user.developers : user.id]
  scope_id    = boundary_scope.arquitectura.id
}

resource "boundary_group" "devops" {
  name        = "devops"
  description = "Group devops"
  member_ids  = [for user in boundary_user.developers : user.id]
  scope_id    = boundary_scope.arquitectura.id
}

resource "boundary_group" "qa" {
  name        = "qa"
  description = "Group qa"
  member_ids  = [for user in boundary_user.developers : user.id]
  scope_id    = boundary_scope.arquitectura.id
}

resource "boundary_group" "developers" {
  name        = "developers"
  description = "Group developers"
  member_ids  = [for user in boundary_user.developers : user.id]
  scope_id    = boundary_scope.arquitectura.id
}



resource "boundary_role" "role_developer" {
  name        = "developer"
  description = "Developer role"
  principal_ids = [boundary_group.developers.id]
  grant_strings = ["id=*;type=*;actions=read"]
  scope_id    = boundary_scope.arquitectura.id
}



resource "boundary_role" "role_devops" {
  name        = "devops"
  description = "Devops role"
  principal_ids = [boundary_group.devops.id]
  grant_strings = ["id=*;type=*;actions=create,read,update,delete"]
  scope_id    = boundary_scope.arquitectura.id
}

resource "boundary_role" "organization_admin" {
  name        = "admin"
  description = "Administrator role"
  principal_ids = concat(
    [for user in boundary_user.developers: user.id]
  )
  grant_strings   = ["id=*;type=*;actions=create,read,update,delete"]
  scope_id = boundary_scope.arquitectura.id
}

resource "boundary_scope" "core_infra" {
  name                   = "Core infrastructure"
  description            = "Project For Infrastructure!"
  scope_id               = boundary_scope.arquitectura.id
  auto_create_admin_role = true
}

resource "boundary_scope" "core_architecture" {
  name                   = "Architecture"
  description            = "Project For Architecture!"
  scope_id               = boundary_scope.arquitectura.id
  auto_create_admin_role = true
}


resource "boundary_scope" "project_consultapp" {
  name                   = "Consultapp"
  description            = "Proyecto consultapp"
  scope_id               = boundary_scope.arquitectura.id
  auto_create_admin_role = true
}

resource "boundary_scope" "project_libroreclamos" {
  name                   = "Libro Reclamos"
  description            = "Proyecto Libro de reclamaciones"
  scope_id               = boundary_scope.arquitectura.id
  auto_create_admin_role = true
}



resource "boundary_host_catalog" "backend_servers" {
  name        = "backend_servers"
  description = "Backend servers host catalog"
  type        = "static"
  scope_id    = boundary_scope.core_infra.id
}

resource "boundary_host" "backend_servers" {
  for_each        = var.backend_server_ips
  type            = "static"
  name            = "backend_server_service_${each.value}"
  description     = "Backend server host"
  address         = each.key
  host_catalog_id = boundary_host_catalog.backend_servers.id
}

resource "boundary_host_set" "backend_servers_ssh" {
  type            = "static"
  name            = "backend_servers_ssh"
  description     = "Host set for backend servers"
  host_catalog_id = boundary_host_catalog.backend_servers.id
  host_ids        = [for host in boundary_host.backend_servers : host.id]
}

# create target for accessing backend servers on port :8000
resource "boundary_target" "backend_servers_service" {
  type         = "tcp"
  name         = "Backend service"
  description  = "Backend service target"
  scope_id     = boundary_scope.core_infra.id
  default_port = "8080"

  host_set_ids = [
    boundary_host_set.backend_servers_ssh .id
  ]
}

# create target for accessing backend servers on port :22
resource "boundary_target" "backend_servers_ssh" {
  type         = "tcp"
  name         = "Backend servers"
  description  = "Backend SSH target"
  scope_id     = boundary_scope.core_infra.id
  default_port = "22"

  host_set_ids = [
    boundary_host_set.backend_servers_ssh.id
  ]
}
