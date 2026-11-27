import Foundation

/// 从 APK 反编译提取的完整接口清单（99 个）。
/// 每个端点标注所属模块与已识别的参数名。
/// `verified` 表示该端点已在真机/脚本中用真实数据跑通。

struct Endpoint {
    let path: String
    let module: String
    let params: [String]
    var verified: Bool = false
    var note: String = ""
}

struct EndpointGroup: Identifiable {
    let title: String
    let items: [Endpoint]
    var id: String { title }
}

enum Endpoints {
    static let all: [Endpoint] = [
        // ---------- 基础 / 登录 ----------
        .init(path: "SIPAIIS_Base/j_spring_security_check", module: "登录",
              params: ["j_username", "j_password", "verCode"], verified: true),
        .init(path: "SIPAIIS_Base/Login/logout.do", module: "登录", params: ["yes"]),
        .init(path: "SIPAIIS_Base/user/getUnitForTree_User.do", module: "组织",
              params: ["userid", "id", "taskId", "processInstanceId"]),
        .init(path: "SIPAIIS_Base/user/getUnitForTree_Workshop.do", module: "组织",
              params: ["userid"], verified: true),
        .init(path: "SIPAIIS_Base/user/getSuperiorUnit.do", module: "组织", params: ["userid"]),
        .init(path: "SIPAIIS_Base/user/getUsers.do", module: "组织", params: ["unitId"]),
        .init(path: "SIPAIIS_Base/user/saveChangePassword.do", module: "设置",
              params: ["oldPassword", "newPassword"]),
        .init(path: "SIPAIIS_Base/user/saveUserPosition.do", module: "定位",
              params: ["userid", "lttd", "lgtd"]),
        .init(path: "SIPAIIS_Base/user/updateUserAppVersion.do", module: "设置", params: []),

        // ---------- 字典 / 文件 ----------
        .init(path: "SIPAIIS_Base/base/dict/data.do", module: "基础", params: ["dictType"]),
        .init(path: "SIPAIIS_Base/base/download.do", module: "文件", params: ["id", "filepath", "nameSpace"]),
        .init(path: "SIPAIIS_Base/base/getFileList.do", module: "文件",
              params: ["taskId", "unitId", "processInstanceId", "masterId", "nameSpace", "tbName"]),
        .init(path: "SIPAIIS_Base/base/getMinioDirectFileList.do", module: "文件",
              params: ["searchName", "nameSpace"]),
        .init(path: "SIPAIIS_Base/base/updateFile.do", module: "文件",
              params: ["recordId", "masterId", "tbName", "nameSpace", "filelist"]),
        .init(path: "SIPAIIS_Base/base/deleteInputFile.do", module: "文件",
              params: ["path", "key", "nameSpace", "tbName"]),

        // ---------- 巡检 ----------
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolRecord/getPatrolRecord4APP.do",
              module: "巡检", params: ["unitId", "userid", "type", "patrolDate", "page", "rows"],
              verified: true),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolPoint/getPatrolPointForRecord4APP.do",
              module: "巡检", params: ["patrolRecordId", "type"], verified: true),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolRecord/updatePatrolPointByAPP.do",
              module: "巡检", params: ["id"], verified: true),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolRecord/updatePatrolRecordByAPP.do",
              module: "巡检", params: ["id", "status"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolContentsRecord/getPatrolContents4APP.do",
              module: "巡检", params: ["patrolRecordId", "patrolPointId", "unitId", "type", "equipmentId"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolContentsRecord/updatePatrolContents.do",
              module: "巡检", params: ["patrolRecordId", "patrolPointId", "json"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolMeasurePointRecord/getPatrolMeasurePoint4APP.do",
              module: "巡检", params: ["patrolRecordId", "patrolPointId", "unitId", "type", "equipmentId"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolMeasurePointRecord/updatePatrolMeasurePoint.do",
              module: "巡检", params: ["id", "json"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolPoint/getList.do",
              module: "巡检", params: ["unitId", "page", "rows"], verified: true),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolPoint/getMPoint4APP.do",
              module: "巡检", params: ["patrolPointId", "unitId", "type"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolPoint/getData.do",
              module: "巡检", params: ["id"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolPoint/simpleUpdate.do",
              module: "巡检", params: ["id", "latitude", "longitude"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolRecord/getEquipmentByPatrolPoint4APP.do",
              module: "巡检", params: ["patrolRecordId", "patrolPointId", "unitId"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/patrolRecord/subEquipment4APP.do",
              module: "巡检", params: ["id"]),
        .init(path: "SIPAIIS_Patrol/timeEfficiency/workerPosition/saveBatch.do",
              module: "定位", params: ["list"]),

        // ---------- 故障 / 缺陷 ----------
        .init(path: "SIPAIIS_DataCenter/maintenance/abnormity/getList.do", module: "故障",
              params: ["unitId", "page", "rows", "status", "search_name"]),
        .init(path: "SIPAIIS_DataCenter/maintenance/abnormity/dosave.do", module: "故障",
              params: ["unitId", "abnormityType", "describe", "id"]),
        .init(path: "SIPAIIS_DataCenter/maintenance/abnormity/doCreateDefectByAbnormal.do",
              module: "故障", params: ["id"]),
        .init(path: "SIPAIIS_DataCenter/maintenance/abnormity/getAbnormityFileList.do",
              module: "故障", params: ["id"]),
        .init(path: "SIPAIIS_Equipment/maintenance/faultLibrary/getList.do", module: "故障",
              params: ["unit_id", "page", "rows", "sel", "unsel"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getTaskList.do", module: "故障",
              params: ["unitId", "pSectionId", "page", "rows", "status", "search_name"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getMDetailList.do", module: "故障",
              params: ["unitId", "pSectionId", "page", "rows", "status", "type"]),
        .init(path: "SIPAIIS_Equipment/maintenance/updateDetail.do", module: "故障",
              params: ["id", "problemresult", "content", "file", "taskId",
                       "processInstanceId", "judgeresult"]),
        .init(path: "SIPAIIS_Equipment/maintenance/updateDetailNoFlow.do", module: "故障",
              params: ["id", "status", "problemresult", "solvetime"]),
        .init(path: "SIPAIIS_Equipment/maintenance/insetMaintenanceDetailNoFlow.do", module: "故障",
              params: ["maintenanceId", "equipmentId", "maintenanceMan", "startDate",
                       "plannedenddt", "planMoney", "problemcontent"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailsByAbnormal.do",
              module: "故障", params: ["abnormalId"]),

        // ---------- 维保 ----------
        .init(path: "SIPAIIS_Equipment/maintenance/getMaintenanceTaskList.do", module: "维保",
              params: ["page", "rows", "search_name", "search_code", "sort", "order"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getListMaintenance.do", module: "维保",
              params: ["page", "rows", "companyid", "begin_time", "end_time", "status"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getListMaintenanceDetail.do", module: "维保",
              params: ["maintenanceId", "page", "rows"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getMaintenanceDetailList.do", module: "维保",
              params: ["id", "type", "page", "rows"]),
        .init(path: "SIPAIIS_Equipment/maintenance/getMDetailList.do", module: "维保",
              params: ["unitId", "page", "rows", "type"]),
        .init(path: "SIPAIIS_Equipment/maintenance/showMaintenanceDetailView.do", module: "维保",
              params: ["taskId", "unitId", "processInstanceId", "id"]),
        .init(path: "SIPAIIS_Equipment/maintenance/showHandleDetail.do", module: "维保",
              params: ["taskId", "processInstanceId", "masterId", "nameSpace"]),
        .init(path: "SIPAIIS_Equipment/maintenance/showAuditDetail.do", module: "维保",
              params: ["taskId", "unitId", "processInstanceId", "id", "masterId"]),
        .init(path: "SIPAIIS_Equipment/maintenance/doHandleDetail.do", module: "维保",
              params: ["id", "processid", "taskid", "businessid", "unitId", "audit",
                       "taskdefinitionkey", "targetusers", "passstatus", "routeNum"]),
        .init(path: "SIPAIIS_Equipment/maintenance/doAuditDetail.do", module: "维保",
              params: ["id", "processid", "taskid", "businessid", "unitid",
                       "taskdefinitionkey", "targetusers", "passstatus", "routeNum", "type"]),

        // ---------- 工作流 ----------
        .init(path: "SIPAIIS_Base/activiti/workflow/getTaskList.do", module: "流程",
              params: ["task", "id"]),
        .init(path: "SIPAIIS_Base/activiti/workflow/task/claim.do", module: "流程",
              params: ["taskId", "users", "businessid", "taskdefinitionkey", "targetusers",
                       "routeNum", "details"]),
        .init(path: "SIPAIIS_Base/activiti/workflow/task/changeUser.do", module: "流程",
              params: ["taskId", "userId"]),
        .init(path: "SIPAIIS_Base/activiti/workflow/getRoutesForSelect2.do", module: "流程",
              params: ["id", "taskId", "passFlag"]),

        // ---------- 报警 ----------
        .init(path: "SIPAIIS_DataCenter/work/scadaAlarm/getAlarmListByCache.do", module: "报警",
              params: ["unitId", "alarmLevel", "alarmType", "stdt", "sort", "order"]),
        .init(path: "SIPAIIS_DataCenter/work/scadaAlarm/confirm.do", module: "报警",
              params: ["alarmId"]),
        .init(path: "SIPAIIS_DataCenter/work/scadaAlarm/saveAlarm.do", module: "报警",
              params: ["alarmLevel", "alarmTypeLv1", "position", "describe",
                       "mpointCode", "mpointName", "status"]),

        // ---------- 排班 ----------
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/getlist.do", module: "排班",
              params: ["unitId", "page", "rows", "status"]),
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/getTaskList.do", module: "排班",
              params: ["id", "page", "rows"]),
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/dostart.do", module: "排班",
              params: ["id"]),
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/doAuditDetail.do", module: "排班",
              params: ["id", "audit"]),
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/showView.do", module: "排班",
              params: ["id"]),
        .init(path: "SIPAIIS_DataCenter/work/processAdjustment/showActCommDetail.do", module: "排班",
              params: ["id"]),

        // ---------- 知识库 ----------
        .init(path: "SIPAIIS_LIBRARY/knowledgeType/tree", module: "知识库", params: ["active"]),
        .init(path: "SIPAIIS_LIBRARY/knowledge/searchDocument", module: "知识库",
              params: ["typeId", "page", "rows", "status", "versiontag"]),
        .init(path: "SIPAIIS_LIBRARY/knowledge/browse", module: "知识库", params: ["id"]),

        // ---------- 测点 / 工艺 ----------
        .init(path: "SIPAIIS_DataCenter/work/mpoint/getlist.do", module: "测点",
              params: ["unitId", "page", "rows", "search_name"]),
        .init(path: "SIPAIIS_DataCenter/work/mpoint/getHistory.do", module: "测点",
              params: ["id", "stdt", "eddt"]),
        .init(path: "SIPAIIS_DataCenter/work/processSection/getlist.do", module: "工艺段",
              params: ["unitId", "page", "rows"]),
        .init(path: "SIPAIIS_DataCenter/work/processSection/getMPointByProcessSection4APP.do",
              module: "工艺段", params: ["pSectionId"]),

        // ---------- 设备 ----------
        .init(path: "SIPAIIS_Equipment/equipment/getList.do", module: "设备",
              params: ["unitId", "pSectionId", "search_name", "page", "rows"]),
        .init(path: "SIPAIIS_Equipment/equipment/doview4Id.do", module: "设备",
              params: ["id", "equipmentId", "patrolPointId", "patrolRecordId", "unitId"]),
        .init(path: "SIPAIIS_Equipment/equipment/doedit.do", module: "设备", params: ["id"]),
        .init(path: "SIPAIIS_Equipment/equipment/equipmentParts/getList.do", module: "设备",
              params: ["equipmentId", "unit_id", "page", "rows"]),
        .init(path: "SIPAIIS_Equipment/equipment/equipmentParts/save.do", module: "设备",
              params: ["partsName", "partsId", "partsSpecification", "unitId", "equipmentId"]),
        .init(path: "SIPAIIS_Equipment/equipment/equipmentClass/getEquipmentClassTree.do",
              module: "设备", params: []),
        .init(path: "SIPAIIS_Equipment/sparepart/goodsClass/search.do", module: "备件",
              params: ["pid", "unit_id", "name", "page", "rows"]),

        // ---------- 视频监控 ----------
        .init(path: "SIPAIIS_Visual/work/camera/getStatusList.do", module: "视频",
              params: ["unitId"], note: "需要大华 SDK"),
        .init(path: "SIPAIIS_Visual/work/camera/getCameraPreview.do", module: "视频",
              params: ["cameraId"], note: "需要大华 SDK"),
        .init(path: "SIPAIIS_Visual/work/camera/getCameraBack.do", module: "视频",
              params: ["cameraId"], note: "需要大华 SDK"),

        // ---------- 大屏 / 可视化 ----------
        .init(path: "SIPAIIS_DataCenter/visual/datacenterVisual4Biz/getBizInfoAll.do",
              module: "看板", params: ["unitId"]),
        .init(path: "SIPAIIS_DataCenter/zone/monitorInfo4Visual.do", module: "看板",
              params: ["unitId", "tags"]),
        .init(path: "SIPAIIS_DataCenter/zone/runInfo4Visual.do", module: "看板",
              params: ["unitId", "stdt", "eddt"]),
        .init(path: "SIPAIIS_DataCenter/zone/getWaterInfo4VisualByFile.do", module: "看板",
              params: ["unitId", "type"]),
        .init(path: "SIPAIIS_DataCenter/zone/getBizWaterDataByFile4GY.do", module: "看板",
              params: ["unitId", "tags"]),
        .init(path: "SIPAIIS_DataCenter/work/scadaPic/getlist4Combo.do", module: "看板",
              params: ["unitId", "page", "rows"]),
        .init(path: "SIPAIIS_DataCenter/work/scadaPic/getMPointList.do", module: "看板",
              params: ["pid"]),
        .init(path: "SIPAIIS_DataCenter/bot/edit.do", module: "助手", params: ["id"]),
    ]

    static var grouped: [EndpointGroup] {
        let order = ["登录", "巡检", "故障", "维保", "报警", "排班", "设备", "测点",
                     "工艺段", "知识库", "看板", "视频", "文件", "组织", "流程", "定位", "设置", "备件", "基础", "助手"]
        var dict: [String: [Endpoint]] = [:]
        for e in all { dict[e.module, default: []].append(e) }
        return order.compactMap { k in
            guard let v = dict[k] else { return nil }
            return EndpointGroup(title: k, items: v)
        }
    }

    static func count(module: String) -> Int {
        all.filter { $0.module == module }.count
    }
}
