
locals {
  bastion_path = "${var.scripts_folder}/clusters/${var.cluster_name}"
}

resource "null_resource" "create_path" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.bastion_path}"
  }
}

resource "local_file" "hosts" {
    depends_on = [null_resource.create_path,oci_core_cluster_network.cluster_network]
    content     = join("\n", local.cluster_instances_ips)
    filename = "${local.bastion_path}/hosts_${var.cluster_name}"
  }

resource "local_file" "inventory" {
  depends_on          = [oci_core_cluster_network.cluster_network]
  content        = templatefile("${path.module}/inventory.tpl", {  
    bastion_name = var.bastion_name,
    bastion_ip = var.bastion_ip, 
    compute = var.node_count > 0 ? zipmap(local.cluster_instances_names, local.cluster_instances_ips) : zipmap([],[])
    public_subnet = var.public_subnet, 
    private_subnet = var.private_subnet, 
    nfs = local.cluster_instances_names[0],
    scratch_nfs = var.use_scratch_nfs,
    cluster_nfs = var.use_cluster_nfs,
    home_nfs = var.home_nfs,
    cluster_nfs_path = var.cluster_nfs_path,
    scratch_nfs_path = var.scratch_nfs_path,
    cluster_network = var.cluster_network,
    slurm = var.slurm,
    spack = var.spack,
    bastion_block = var.bastion_block,
    scratch_nfs_type = local.scratch_nfs_type,
    bastion_mount_ip = var.bastion_mount_ip,
    cluster_mount_ip = local.mount_ip,
    cluster_name = local.cluster_name,
    shape = var.cluster_network ? var.cluster_network_shape : var.instance_pool_shape
    })
  filename   = "${local.bastion_path}/inventory"
}


resource "null_resource" "configure" {
  depends_on          = [oci_core_cluster_network.cluster_network,local_file.inventory,local_file.hosts]
  provisioner "local-exec" {
    command = "timeout 30m ${var.scripts_folder}/configure.sh ${local.cluster_name}"  
  }
}

resource "null_resource" "on_destroy" {
  depends_on = [local_file.inventory]
  triggers = {
    scripts_folder = var.scripts_folder
    cluster_name = local.cluster_name
    bastion_path = local.bastion_path
  }
  provisioner "local-exec" {
    command = "${self.triggers.scripts_folder}/cleanup.sh ${self.triggers.cluster_name}; rm -rf ${self.triggers.bastion_path}"
    when    = destroy
    on_failure = continue
  }
}
