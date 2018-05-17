Nova 控制着一个个虚拟机的状态变迁和生命周期，这种对虚拟机生命周期的管理是由 nova-compute service 来完成的。 

在 Create Instance 之前，需要为 Instance 指定一组资源(Disk/Memory/VCPU/RootDisk/EphemeralDisk/Swap)。 
nova-compute 在执行创建之前，需要通过这些资源配置来判断是否由足够的 Host 资源来实现创建。这组资源的设置就是 flavor，即创建虚拟机的规格。每个 Instance 对象的 instance_type_id 字段就表示该 Instance 所拥有的 flavor 。


- 在nova.api.openstack.compute.services.py中定义了一个create()函数，唯一入口：

```
def create(self, req, body):
        """Creates a new server for a given user."""
        #主要任务是从传递过的req中获取各种创建虚拟机所需要的参数信息，并做验证，然后将获取的一系列参数（inst_type,image_uuid,name等）作为nova/compute/api.py中的API类的create()方法参数，进行下一步处理。
        (instances, resv_id) = self.compute_api.create(context,
                            inst_type,
                            image_uuid,
                            display_name=name,
                            display_description=description,
                            availability_zone=availability_zone,
                            forced_host=host, forced_node=node,
                            metadata=server_dict.get('metadata', {}),
                            admin_password=password,
                            requested_networks=requested_networks,
                            check_server_group_quota=True,
                            **create_kwargs)

```
- 跳转到nova.compute.api.py:API.create():

```
@hooks.add_hook("create_instance")
def create(self, context, instance_type,
               image_href, kernel_id=None, ramdisk_id=None,
               min_count=None, max_count=None,
               display_name=None, display_description=None,
               key_name=None, key_data=None, security_group=None,
               availability_zone=None, forced_host=None, forced_node=None,
               user_data=None, metadata=None, injected_files=None,
               admin_password=None, block_device_mapping=None,
               access_ip_v4=None, access_ip_v6=None, requested_networks=None,
               config_drive=None, auto_disk_config=None, scheduler_hints=None,
               legacy_bdm=True, shutdown_terminate=False,
               check_server_group_quota=False):
                                        
def _create_instance(self, context, instance_type,
               image_href, kernel_id, ramdisk_id,
               min_count, max_count,
               display_name, display_description,
               key_name, key_data, security_groups,
               availability_zone, user_data, metadata, injected_files,
               admin_password, access_ip_v4, access_ip_v6,
               requested_networks, config_drive,
               block_device_mapping, auto_disk_config, filter_properties,
               reservation_id=None, legacy_bdm=True, shutdown_terminate=False,
               check_server_group_quota=False):
        """Verify all the input parameters regardless of the provisioning
        strategy being performed and schedule the instance(s) for
        creation.
        """

    self.compute_task_api.build_instances(context,
                instances=instances, image=boot_meta,
                filter_properties=filter_properties,
                admin_password=admin_password,
                injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping,
                legacy_bdm=False)
    return (instances, reservation_id)
```

- 跳转到nova.conductor.api.py:ComputeTaskAPI.build_instances():

```
def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping, legacy_bdm=True):
        self.conductor_compute_rpcapi.build_instances(context,
                instances=instances, image=image,
                filter_properties=filter_properties,
                admin_password=admin_password, injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping,
                legacy_bdm=legacy_bdm)
```

- 跳转到nova.conductor.rpcapi.py:ComputeTaskAPI.build_instances():

```
def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping, legacy_bdm=True):
        image_p = jsonutils.to_primitive(image)
        version = '1.10'
        if not self.client.can_send_version(version):
            version = '1.9'
            if 'instance_type' in filter_properties:
                flavor = filter_properties['instance_type']
                flavor_p = objects_base.obj_to_primitive(flavor)
                filter_properties = dict(filter_properties,
                                         instance_type=flavor_p)
        kw = {'instances': instances, 'image': image_p,
               'filter_properties': filter_properties,
               'admin_password': admin_password,
               'injected_files': injected_files,
               'requested_networks': requested_networks,
               'security_groups': security_groups}
        if not self.client.can_send_version(version):
            version = '1.8'
            kw['requested_networks'] = kw['requested_networks'].as_tuples()
        if not self.client.can_send_version('1.7'):
            version = '1.5'
            bdm_p = objects_base.obj_to_primitive(block_device_mapping)
            kw.update({'block_device_mapping': bdm_p,
                       'legacy_bdm': legacy_bdm})

        cctxt = self.client.prepare(version=version)
        cctxt.cast(context, 'build_instances', **kw)
```

- 创建虚拟机属于TaskAPI任务，所有的TaskAPI都交由nova-conductor来处理，所以manager.py的实现在Conductor中，即nova.conductor.manager.py:ComputeTaskManager.build_instances()：

```

class ComputeTaskManager(base.Base):
    """Namespace for compute methods.

    This class presents an rpc API for nova-conductor under the 'compute_task'
    namespace.  The methods here are compute operations that are invoked
    by the API service.  These methods see the operation to completion, which
    may involve coordinating activities on multiple compute nodes.
    """

    target = messaging.Target(namespace='compute_task', version='1.15')

    def __init__(self):
        super(ComputeTaskManager, self).__init__()
        self.compute_rpcapi = compute_rpcapi.ComputeAPI()
        self.image_api = image.API()
        self.network_api = network.API()
        self.servicegroup_api = servicegroup.API()
        self.scheduler_client = scheduler_client.SchedulerClient()
        self.notifier = rpc.get_notifier('compute', CONF.host)
        
        # 其中 Scheduler client 是对 Scheduler_rpcapi 的封装，本质上是一个 Scheduler 提供的 rpcapi：
        #    nova.manager.ComputeTaskManager:scheduler_client 
        #        ==> nova.scheduler.client.__init__:__init__ 
        #             ==> nova.scheduler.client.query.SchedulerQueryClient:__init__
        #                 ==> self.scheduler_rpcapi = scheduler_rpcapi.SchedulerAPI()
        ...
        # 1.（被调用） HTTP Request ==> nova.api ==> RPC cast ==> nova-conductor (nova.conductor.manager:ComputeTaskManager.build_instances() 是 nova.conductor.rpcapi.build_instances RPC 接口的实际功能实现函数)     
        # 参数传递过程： nova-api 调用 conductor.rpcapi:build_instances() 并传入实参 
        #                 ==> 将实参和其他信息打包发送到消息队列(数据流形式) 
        #                    ==> 将实参传入 conductor.manager:build_instances() ; 

    def build_instances(self, context, instances, image, filter_properties,
            admin_password, injected_files, requested_networks,
            security_groups, block_device_mapping=None, legacy_bdm=True):        
        # request_spec 是一个字典类型，包含了详细的虚拟机信息，nova-scheduler 依据这些信息来选择一个最佳的主机并返回给 nova-conductor
        ...
        # 2.（调用） nova-conductor 通过 RPC call 方式调用 nova-scheduler 的接口函数： nova.scheduler.rpcapi:select_destinations()
        # 通过 nova-scheduler 来获取 HOSTS 
        hosts = self.scheduler_client.select_destinations(context, request_spec, filter_properties)
        ...
        
        # 3.（调用） nova-conductor ==> RPC cast ==> nova-compute （nova.compute.build_and_run_instance()）  
    def build_and_run_instance(self, ctxt, instance, host, image, request_spec,
            filter_properties, admin_password=None, injected_files=None,
            requested_networks=None, security_groups=None,
            block_device_mapping=None, node=None, limits=None):

        version = '4.0'
        cctxt = self.router.by_host(ctxt, host).prepare(
                server=host, version=version)
        cctxt.cast(ctxt, 'build_and_run_instance', instance=instance,
                image=image, request_spec=request_spec,
                filter_properties=filter_properties,
                admin_password=admin_password,
                injected_files=injected_files,
                requested_networks=requested_networks,
                security_groups=security_groups,
                block_device_mapping=block_device_mapping, node=node,
                limits=limits)               
```
- 终于进入nova.compute.manager.py:ComputeManager.build_and_run_instance():

```
def build_and_run_instance(self, context, instance, image, request_spec,
                     filter_properties, admin_password=None,
                     injected_files=None, requested_networks=None,
                     security_groups=None, block_device_mapping=None,
                     node=None, limits=None):

    @utils.synchronized(instance.uuid)
    def _locked_do_build_and_run_instance(*args, **kwargs):
        # NOTE(danms): We grab the semaphore with the instance uuid
        # locked because we could wait in line to build this instance
        # for a while and we want to make sure that nothing else tries
        # to do anything with this instance while we wait.
        with self._build_semaphore:
                self._do_build_and_run_instance(*args, **kwargs)

        # NOTE(danms): We spawn here to return the RPC worker thread back to
        # the pool. Since what follows could take a really long time, we don't
        # want to tie up RPC workers.

    utils.spawn_n(_locked_do_build_and_run_instance,
                      context, instance, image, request_spec,
                      filter_properties, admin_password, injected_files,
                      requested_networks, security_groups,
                      block_device_mapping, node, limits)
```

- 代码在nova.compute.manager.py:ComputeManager

```
class ComputeManager(manager.Manager):
    """Manages the running instances from creation to destruction."""

    target = messaging.Target(version='4.13')

    # How long to wait in seconds before re-issuing a shutdown
    # signal to an instance during power off.  The overall
    # time to wait is set by CONF.shutdown_timeout.
    SHUTDOWN_RETRY_INTERVAL = 10

    def __init__(self, compute_driver=None, *args, **kwargs):
        """Load configuration options and connect to the hypervisor."""
        
        super(ComputeManager, self).__init__(service_name="compute",
                                             *args, **kwargs)

        # NOTE(russellb) Load the driver last.  It may call back into the
        # compute manager via the virtapi, so we want it to be fully
        # initialized before that happens.
        self.driver = driver.load_compute_driver(self.virtapi, compute_driver)
        self.use_legacy_block_device_info = \
                            self.driver.need_legacy_block_device_info
        # 加载 Driver, 过程如下：
        # nova.virt.driver:load_compute_driver()
        #     ==> oslo_utils.importutils:import_object_ns()
        #     ==> nova.utils:check_isinstance() 
        # Return： 一个由 (compute_driver = CONF.compute_driver) 决定的 ComputeDriver 实例化对象 driver
        
    def _build_and_run_instance(self, context, instance, image, injected_files,
            admin_password, requested_networks, security_groups,
            block_device_mapping, node, limits, filter_properties):
        image_name = image.get('name') 
            # ==> nova.image.__init__
            #     ==> nova.image.api.API:get()
            #         ==> nova.image.api.API:_get_session_and_image_id()
            #             ==> nova.image.glance:get_remote_image_service()
            #                 ==> nova.image.glance.GlanceImageService:show()   
            #                     ==> nova.image.glance._tnslate_from_glanceranslate_from_glance
            # Return:ClanceImageService.show() 返回一个包含了 Image_Mete 信息的 Dict['name'] == uri_or_id
        
        #向外部发出一个 start to create instance 的通知
        self._notify_about_instance_usage(context, instance, 'create.start',
                extra_usage_info={'image_name': image_name})
        #应用 claim 机制 Update table:compute_nodes
        try:
            rt = self._get_resource_tracker(node)
            with rt.instance_claim(context, instance, limits):
                # NOTE(russellb) It's important that this validation be done
                # *after* the resource tracker instance claim, as that is where
                # the host is set on the instance.
                self._validate_instance_group_policy(context, instance,
                        filter_properties)
                image_meta = objects.ImageMeta.from_dict(image)
                with self._build_resources(context, instance,
                        requested_networks, security_groups, image_meta,
                        block_device_mapping) as resources:
                    instance.vm_state = vm_states.BUILDING
                    instance.task_state = task_states.SPAWNING
                    # NOTE(JoshNang) This also saves the changes to the
                    # instance from _allocate_network_async, as they aren't
                    # saved in that function to prevent races.
                    instance.save(expected_task_state=
                            task_states.BLOCK_DEVICE_MAPPING)
                    block_device_info = resources['block_device_info']
                    network_info = resources['network_info']
                    LOG.debug('Start spawning the instance on the hypervisor.',
                              instance=instance)
                    with timeutils.StopWatch() as timer:
                        #由 nova.virt.driver.ComputeDriver 实例化对象 driver调用spawn()函数来进行虚拟机的创建
                        self.driver.spawn(context, instance, image_meta,
                                          injected_files, admin_password,
                                          network_info=network_info,
                                          block_device_info=block_device_info)


```

- Resource Tracker

nova-compute 需要在数据库中存储 Host 的资源使用情况，以便于 nova-scheduler 获取作为选择 Host 依据的数据。Node Project 使用 ConputeNode 数据库表对象来保存 Compute Node的配置信息和资源使用情况(/opt/stack/nova/nova/objects/compute_node.py)。所以 nova-compute 会为每一个 Host 创建一个 ResourceTracker 对象，用于更新 ComputeNode 对象在数据库中对应的 compute_nodes 表。

有两种更新*compute_nodes*表的方式：

- Claim 机制：在创建 Instance 之前，预先测试 Host 的可用资源能否满足 Create Instance。如果满足，则首先更新数据库，将虚拟机申请的资源从可用资源中减去。 如果后来创建失败或者将虚拟机删除时，会再通过 Claim 将原来减去的部分再添加到可用资源中去。实现：nova.compute.resource_tracker:instance_claims

- Periodic Task：在 nova.compute.manager.ComputeManager 中有个周期性任务 update_available_resource() 用于更新 Host 的资源数据。

NOTE：上面两种数据库更新方式并不冲突。Claim 实在数据库当前数据的基础上去计算并更新，可以保证数据库里可用资源的及时更新。 Periodic Task 是为了数据库内信息的准确性，它每次执行都会通过 Hypervisor 去获取 Host 的信息，并将这些信息更新到数据库中。前者是在 Create Instance 的时候执行，后者是周期性执行。



