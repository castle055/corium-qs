pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import QtCore

Singleton {
    id: root

    readonly property string thumbnailDir: Quickshell.env("HOME") +
                                           "/.cache/quickshell/corium/notebook-thumbnails/"

    readonly property string templateDir: (StandardPaths.writableLocation(StandardPaths.AppDataLocation) + "/corium/notebook-templates/").substring(7)

    function open(file) {
        Quickshell.execDetached(["xournalpp", file])
    }

    // function createNewNotebook()

    function createNewVolume(notebook: string, volumeName: string, template: string) {
        lookupTemplate(notebook, template, (templatePath) => {
            const newVolumePath = notebook + "/" + volumeName
            console.log(`Creating volume... path: ${newVolumePath}, template: ${templatePath}`)

            run_script("cp \"$1\" \"$2\"",
                       ["sh", templatePath, newVolumePath],
                       (exitCode, stdout, stderr) => {
                           //console.log(stdout)
                           //console.log(stderr)
                       })
            open(newVolumePath)
        })
    }

    function lookupTemplate(notebookPath: string, template: string, callback) {
        const notebookLocal = notebookPath + "/.templates/" + template + ".xopp"
        run(["test", "-f", notebookLocal],
            (exitCode, stdout, stderr) => {
                if (exitCode === 0) {
                    callback(notebookLocal)
                } else {
                    const globalTemplate = templateDir + template + ".xopp"
                    run(["test", "-f", globalTemplate],
                        (exitCode, stdout, stderr) => {
                            if (exitCode === 0) {
                                callback(globalTemplate)
                            } else {
                                callback(getDefaultTemplate())
                            }
                        })

                }
            })
    }


    function getDefaultTemplate() {
        return templateDir + "default.xopp"
    }

    function getPageCount(path, callback) {
        if (path.toLowerCase().endsWith(".xopp")) {
            run_script(
                        "gzip -dc \"$1\" | xmllint --xpath 'count(/xournal/page)' -",
                        ["sh", path],
                        (exitCode, stdout, stderr) => {
                            if (exitCode !== 0) {
                                callback(-1)
                                return
                            }

                            let count = parseInt(stdout.trim())

                            callback(isNaN(count) ? -1 : count)
                        })
        } else if (path.toLowerCase().endsWith(".pdf")) {
            run_script(
                        "pdfinfo \"$1\" | grep '^Pages:' | awk '{print $2}'",
                        ["sh", path],
                        (exitCode, stdout, stderr) => {
                            if (exitCode !== 0) {
                                callback(-1)
                                return
                            }

                            let count = parseInt(stdout.trim())

                            callback(isNaN(count) ? -1 : count)
                        })
        }
    }

    function generateThumbnail(path, mTime, callback) {
        if (!path.toLowerCase().endsWith(".xopp") && !path.toLowerCase().endsWith(".pdf"))
            return

        withThumbnailCacheDir(() => {
            let hash = Qt.md5(path)
            let thumbnailPath = `${root.thumbnailDir}${hash}_${mTime.getFullYear()}${String(mTime.getMonth()+1).padStart(2, '0')}${String(mTime.getDate()).padStart(2, '0')}_${String(mTime.getHours()).padStart(2, '0')}${String(mTime.getMinutes()).padStart(2, '0')}${String(mTime.getSeconds()).padStart(2, '0')}.png`
            //console.log(`${root.thumbnailDir}${hash}_${mTime.getFullYear()}${String(mTime.getMonth()+1).padStart(2, '0')}${String(mTime.getDate()).padStart(2, '0')}_${String(mTime.getHours()).padStart(2, '0')}${String(mTime.getMinutes()).padStart(2, '0')}${String(mTime.getSeconds()).padStart(2, '0')}.png`)

            run(["test", "-f", thumbnailPath],
                (exitCode, stdout, stderr) => {
                    if (exitCode === 0) {
                        callback(thumbnailPath)
                    } else {
                        run_script(`find "${root.thumbnailDir}" | grep "${hash}" | xargs -d "\n" rm`, ["sh"],
                                   (exitCode, stdout, stderr) => {
                                       if (path.toLowerCase().endsWith(".xopp")) {
                                           run([
                                                   "xournalpp-thumbnailer",
                                                   path,
                                                   thumbnailPath
                                               ], (exitCode, stdout, stderr) => {
                                                   if (exitCode !== 0) {
                                                       return
                                                   }

                                                   callback(thumbnailPath)
                                               })
                                       } else if (path.toLowerCase().endsWith(".pdf")) {
                                           thumbnailPath = thumbnailPath.substring(0, thumbnailPath.length-4)

                                           run([
                                                   "pdftoppm",
                                                   "-f", "1",
                                                   "-singlefile",
                                                   "-png",
                                                   "-r", "100",
                                                   path,
                                                   thumbnailPath
                                               ], (exitCode, stdout, stderr) => {
                                                   if (exitCode !== 0) {
                                                       return
                                                   }

                                                   callback(thumbnailPath)
                                               })
                                       }
                                   })
                    }
                })

        })
    }

    function withThumbnailCacheDir(callback) {
        run([
                "mkdir",
                "-p",
                root.thumbnailDir
            ], (exitCode, stdout, stderr) => {
                if (exitCode !== 0) {
                    return
                }

                callback()
            })
    }

    function run(command, callback) {
        let operation = runCommandProcess.createObject( null, { command: command })

        operation.finished.connect((exitCode, stdout, stderr) => {
            callback(exitCode, stdout, stderr)
        })

        operation.start()
    }


    function run_script(script, args, callback) {
        run([
                "sh",
                "-c",
                script,
                ...args
            ], callback)
    }

    Component {
        id: runCommandProcess

        Item {
            id: operation

            property list<string> command

            signal finished(int exitCode, string stdout, string stderr)

            Process {
                id: process

                command: operation.command

                stdout: StdioCollector {
                    id: stdoutCollector
                }

                stderr: StdioCollector {
                    id: stderrCollector
                }

                onExited: function(exitCode, exitStatus) {
                    operation.finished(
                                exitCode,
                                stdoutCollector.text,
                                stderrCollector.text
                                )
                    
                    operation.destroy()
                }
            }

            function start() {
                process.running = true
            }
        }
    }
}
