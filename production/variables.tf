variable "amf_ip" {
  type = string
  description = "IPv4 address assigned to the AMF LoadBalancer"
}

variable "amf_hostname" {
  type = string
  description = "Hostname pointing to the AMF LoadBalancer"
}

variable "gnb_subnet" {
  type = string
  description = "Subnet used by the gNodeBs, in CIDR notation"
}

variable "nms_domainname" {
  type = string
  description = "Domain name used by Traefik for Ingress to the NMS"
}

variable "upf_access_gateway_ip" {
  type = string
  description = "IPv4 address of the gateway used by the access interface"
}

variable "upf_access_ip" {
  type = string
  description = "IPv4 address of the access interface, in CIDR notation"
}

variable "upf_access_mac" {
  type = string
  description = "MAC address of the access interface"
}

variable "upf_core_gateway_ip" {
  type = string
  description = "IPv4 address of the gateway used by the core interface"
}

variable "upf_core_ip" {
  type = string
  description = "IPv4 address of the core interface, in CIDR notation"
}

variable "upf_core_mac" {
  type = string
  description = "MAC address of the core interface"
}

variable "upf_enable_hw_checksum" {
  type = bool
  description = "Enables hardware offloaded checksum calculations in the UPF"
  
  default = "true"
}

variable "upf_enable_nat" {
  type = bool
  description = "Enables Network Address Translation in the UPF"

  default = "false"
}

variable "upf_hostname" {
  type = string
  description = "Hostname pointing to the UPF LoadBalancer"
}
