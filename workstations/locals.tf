locals {
  # Database engines a workstation can ask for.
  db_engines = {
    mysql = {
      engine      = "mysql"
      version     = "8.0"
      port        = 3306
      default_db  = "labdb"
      master_user = "admin"
    }
    sqlserver = {
      engine      = "sqlserver-ex"
      version     = "16.00"
      port        = 1433
      default_db  = null # RDS SQL Server rejects a database name at creation
      master_user = "admin"
    }
    postgres = {
      engine      = "postgres"
      version     = "16"
      port        = 5432
      default_db  = "labdb"
      master_user = "postgres"
    }
  }

  # Apps a workstation can ask for. Installers live in the catalog bucket at
  # apps/<app>/<version>/<file>.
  #   type     = installer family; picks the silent flags (modules/workstation)
  #   args     = extra arguments for this installer
  #   registry = regex matched against the Windows programs list, as proof of install
  #   runtime  = installed before the regular apps
  app_catalog = {
    "7zip"          = { file = "7zip-x64.msi", type = "msi", args = [], registry = "^7-Zip", runtime = false }
    chrome          = { file = "chrome-x64.msi", type = "msi", args = [], registry = "^Google Chrome", runtime = false }
    notepadplusplus = { file = "notepadplusplus-x64.exe", type = "nsis", args = [], registry = "^Notepad\\+\\+", runtime = false }
    vscode          = { file = "vscode-x64.exe", type = "inno", args = ["/MERGETASKS=!runcode"], registry = "^Microsoft Visual Studio Code", runtime = false }
    # Needs /allusers next to /S, or it exits 666660 without installing.
    dbeaver = { file = "dbeaver-x64.exe", type = "nsis", args = ["/allusers"], registry = "^DBeaver", runtime = false }
    odbc17  = { file = "odbc17-x64.msi", type = "msi", args = ["IACCEPTMSODBCSQLLICENSETERMS=YES"], registry = "ODBC Driver 17 for SQL Server", runtime = true }
    # Full installer: the small bootstrapper would download from the internet.
    webview2 = { file = "webview2-x64.exe", type = "webview2", args = [], registry = "Microsoft Edge WebView2", runtime = true }
  }

  # Each workstation's apps, runtimes first, with the bucket key of each installer.
  workstation_apps = {
    for name, w in var.workstations : name => [
      for app in concat(
        sort([for a in keys(w.apps) : a if local.app_catalog[a].runtime]),
        sort([for a in keys(w.apps) : a if !local.app_catalog[a].runtime]),
        ) : merge(local.app_catalog[app], {
          name    = app
          version = w.apps[app]
          key     = "apps/${app}/${w.apps[app]}/${local.app_catalog[app].file}"
      })
    ]
  }

  # Every installer some workstation needs: what the catalog check looks for.
  requested_installers = distinct(flatten([for apps in values(local.workstation_apps) : [for a in apps : a.key]]))

  # Databases derived from what the workstations asked for.
  requested_engines = toset(flatten([for w in var.workstations : w.databases]))
}
