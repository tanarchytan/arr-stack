#!/bin/bash
cd /opt/stacks || exit

# Check for changes
if [[ -z $(git status -s) ]]; then
  echo "No changes to commit."
  exit 0
fi

echo "Changes detected. Committing..."
git add .
git commit -m "Auto-backup: Config update $(date +'%Y-%m-%d %H:%M')"
git push origin main
echo "✅ Pushed to Git."
