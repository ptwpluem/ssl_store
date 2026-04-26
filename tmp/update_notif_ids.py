import os

file_path = '/Users/piti/Documents/is767/workspace/ssl_store_v2/lib/services/mock_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace the notifId generation
# We need to make sure we have access to _idGeneratorService in these methods.
# All spots where notifId is generated like this are already in MockService which has _idGeneratorService.

new_content = content.replace(
    'final notifId = DateTime.now().millisecondsSinceEpoch.toString();',
    'final notifId = await _idGeneratorService.generateId(\'notifications\');'
)

# 2. Replace the doc reference
new_content = new_content.replace(
    '.doc(\'n_$notifId\');',
    '.doc(notifId);'
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Successfully replaced notification ID logic.")
