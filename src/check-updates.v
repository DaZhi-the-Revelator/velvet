module main

import cli
import net.http
import json
import term
import metadata

struct GithubRelease {
	tag_name string @[json: 'tag_name']
}

fn check_updates_cmd(_ cli.Command) ! {
	local_version := metadata.manifest.version.trim_space()

	infoln('Checking for velvet updates...')
	infoln('Local version: ${local_version}')

	resp := http.get('https://api.github.com/repos/DaZhi-the-Revelator/velvet/releases/latest') or {
		return error('Failed to reach GitHub API: ${err}')
	}

	if resp.status_code != 200 {
		return error('GitHub API returned status ${resp.status_code}')
	}

	release := json.decode(GithubRelease, resp.body) or {
		return error('Failed to parse GitHub API response: ${err}')
	}

	remote_version := release.tag_name.trim_left('v').trim_space()

	if remote_version == '' {
		return error('Could not determine latest release version')
	}

	infoln('Latest release: ${remote_version}')

	if local_version == remote_version {
		successln('velvet is up to date (${local_version})')
	} else {
		println('${term.yellow('[UPDATE]')} velvet ${remote_version} is available (you have ${local_version})')
		println('')
		println('To update, run:')
		println('  cd velvet && git pull && v run build.vsh release')
		println('  then copy bin/velvet to your PATH')
	}
}
