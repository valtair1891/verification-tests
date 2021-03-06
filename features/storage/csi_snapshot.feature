Feature: Volume snapshot test

  # @author wduan@redhat.com
  @admin
  Scenario Outline: Volume snapshot create and restore test
    Given I have a project  
    Given I obtain test data file "storage/misc/pvc.json"
    When I create a dynamic pvc from "pvc.json" replacing paths:
      | ["metadata"]["name"]         | mypvc-ori |
      | ["spec"]["storageClassName"] | <csi-sc>  |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-ori  |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-ori  |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-ori" becomes ready
    When I execute on the pod:
      | sh | -c | echo "snapshot test" > /mnt/local/testfile |
    Then the step should succeed
    And I execute on the pod:
      | sh | -c | sync -f /mnt/local/testfile |
    Then the step should succeed
    Given I ensure "mypod-ori" pod is deleted

    Given admin creates a VolumeSnapshotClass replacing paths:
      | ["metadata"]["name"] | snapclass-<%= project.name %> |
    Given I obtain test data file "storage/csi/volumesnapshot_v1.yaml"
    When I run oc create over "volumesnapshot_v1.yaml" replacing paths:
      | ["metadata"]["name"]                            | mysnapshot                    |
      | ["spec"]["volumeSnapshotClassName"]             | snapclass-<%= project.name %> |
      | ["spec"]["source"]["persistentVolumeClaimName"] | mypvc-ori                     |
    Then the step should succeed
    And the "mysnapshot" volumesnapshot becomes ready
    Given I obtain test data file "storage/csi/pvc-snapshot.yaml"
    When I create a dynamic pvc from "pvc-snapshot.yaml" replacing paths:
      | ["metadata"]["name"]           | mypvc-snap |
      | ["spec"]["storageClassName"]   | <csi-sc>   |
      | ["spec"]["dataSource"]["name"] | mysnapshot |
    Then the step should succeed
    Given I obtain test data file "storage/misc/pod.yaml"
    When I run oc create over "pod.yaml" replacing paths:
      | ["metadata"]["name"]                                         | mypod-snap |
      | ["spec"]["volumes"][0]["persistentVolumeClaim"]["claimName"] | mypvc-snap |
      | ["spec"]["containers"][0]["volumeMounts"][0]["mountPath"]    | /mnt/local |
    Then the step should succeed
    Given the pod named "mypod-snap" becomes ready
    And the "mypvc-snap" PVC becomes :bound 
    When I execute on the "mypod-snap" pod:
      | sh | -c | more /mnt/local/testfile |
    Then the step should succeed
    And the output should contain "snapshot test"
    
    Examples:
      | csi-sc  |
      | gp2-csi | # @case_id OCP-27727
