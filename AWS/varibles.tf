variable "region" {
   type = string
   description = "Region where we will create our resources"
   default     = "eu-central-1"
}

#Availability zones
variable "azs" {
  type = list(string)
  description = "Availability zones"
}