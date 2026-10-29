-- Reels are videos; regular posts remain image uploads.
update storage.buckets
set allowed_mime_types = array[
  'image/jpeg',
  'image/png',
  'image/webp',
  'video/mp4',
  'video/quicktime',
  'video/webm'
]
where id = 'posters';
