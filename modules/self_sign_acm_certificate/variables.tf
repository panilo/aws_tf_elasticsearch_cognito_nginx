variable "domain_name" {
  type = string
}

variable "organization" {
  type    = string
  default = ""
}

variable "organizational_unit" {
  type    = string
  default = ""
}

variable "street_address" {
  type    = list(string)
  default = []
}

variable "locality" {
  type    = string
  default = "Dublin"
}

variable "province" {
  type    = string
  default = "Dublin"
}

variable "country" {
  type    = string
  default = "IE"
}

variable "postal_code" {
  type    = string
  default = ""
}

variable "serial_number" {
  type    = string
  default = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
