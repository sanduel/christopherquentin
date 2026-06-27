namespace :gallery do
  desc "Convert legacy PhotoSubmissions into GalleryPhotos (idempotent)"
  task absorb_submissions: :environment do
    already = ActiveStorage::Attachment
      .where(record_type: "GalleryPhoto", name: "photo").pluck(:blob_id).to_set

    converted = 0
    skipped = 0
    PhotoSubmission.find_each do |sub|
      sub.photos.each do |attachment|
        if already.include?(attachment.blob_id)
          skipped += 1
          next
        end
        photo = GalleryPhoto.new(status: sub.status, submitter_name: sub.name, submitter_email: sub.email)
        photo.photo.attach(attachment.blob)
        photo.save!
        already << attachment.blob_id
        converted += 1
      end
    end
    puts "Absorbed #{converted} submission photo(s) into the gallery (#{skipped} already present)."
  end
end
