(.spec.bootstrap.recovery // .spec.bootstrap.initdb // {}) as $appdb
| {
    apiVersion,
    kind,
    metadata: {
      name: .metadata.name,
      namespace: .metadata.namespace,
      annotations: {
        "cnpg.io/skipEmptyWalArchiveCheck": "enabled"
      }
    },
    spec: (
      .spec
      | .bootstrap = {
          recovery: {
            database: ($appdb.database // $app),
            owner: ($appdb.owner // $app),
            source: "origin",
            recoveryTarget: {
              backupID: $backup,
              targetImmediate: true
            }
          }
        }
    )
  }
