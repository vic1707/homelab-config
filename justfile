sftp host user:
	#!/usr/bin/env bash
	set -euo pipefail
	sb_user=`gopass show {{host}}/{{user}}.account user`
	sftp -i .ssh/{{host}}/{{user}} "$sb_user@$sb_user.your-storagebox.de"

ssh host user:
	#!/usr/bin/env bash
	set -euo pipefail
	sb_user=`gopass show {{host}}/{{user}}.account user`
	ssh -i .ssh/{{host}}/{{user}} "$sb_user@$sb_user.your-storagebox.de" -p 23
