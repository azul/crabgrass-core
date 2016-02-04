require 'test_helper'

class AssetTest < ActiveSupport::TestCase


  def setup
    setup_assets
  end

  def teardown
    teardown_assets
  end

  def test_associations
    assert check_associations(Asset)
    assert check_associations(Asset::Version)
    assert check_associations(Thumbnail)
  end

  def test_single_table_inheritance
    @asset = FactoryGirl.create :png_asset
    assert_equal 'Png', @asset.type, 'initial asset should be a png'
    assert_equal 'image/png', @asset.content_type, 'initial asset should be a png'

    @asset.uploaded_data = upload_data('photo.jpg')
    @asset.save
    assert_equal 'Image', @asset.type, 'then the asset should be a jpg'
    assert_equal 'image/jpeg', @asset.content_type, 'then the asset should be a jpg'
  end

  def test_versions
    @asset = FactoryGirl.create :png_asset
    @id = @asset.id
    @filename_for_1 = @asset.private_filename
    assert_equal 1, @asset.version, 'should be on version 1'

    @asset.uploaded_data = upload_data('photo.jpg')
    @asset.save
    @filename_for_2 = @asset.private_filename
    assert_equal 2, @asset.version, 'should be on version 2'
    assert_equal 2, @asset.versions.size, 'there should be two versions'

    assert !File.exist?(@filename_for_1), 'first non-version file should not exist'
    assert File.exist?(@filename_for_2), 'second non-version file should exist'

    @version = @asset.versions.earliest
    assert_equal @version.class, Asset::Version
    assert_equal 'Png', @version.versioned_type
    assert_equal 'image.png', @version.filename

    #puts @version.inspect
    #puts @version.thumbdefs.inspect
    #puts @version.thumbnail_filename(:small)
    assert_equal 'image_small.png', @version.thumbnail_filename(:small)
    assert_equal "/assets/#{@id}/versions/1/image.png", @version.url
    assert read_file('image.png') == File.read(@version.private_filename), 'version 1 data should match image.png'

    @version = @asset.versions.latest
    assert_equal 'Image', @version.versioned_type
    assert_equal 'photo.jpg', @version.filename
    assert_equal 'photo_small.jpg', @version.thumbnail_filename(:small)
    assert_equal "/assets/#{@id}/versions/2/photo.jpg", @version.url
    assert read_file('photo.jpg') == File.read(@version.private_filename), 'version 2 data should match photo.jpg'
  end

  def test_rename
    @asset = FactoryGirl.create :png_asset
    @asset.base_filename = 'newimage'
    @asset.save

    assert_equal "%s/0000/%04d/newimage.png" % [ASSET_PRIVATE_STORAGE,@asset.id], @asset.private_filename
    assert File.exist?(@asset.private_filename)
    assert !File.exist?("%s/0000/%04d/image.png" % [ASSET_PRIVATE_STORAGE,@asset.id])
  end

  def test_file_cleanup_on_destroy
    @asset = FactoryGirl.create :png_asset
    @asset.update_access
    @asset.destroy

    assert !File.exist?(@asset.private_filename), 'private file should not exist'
    assert !File.exist?(File.dirname(@asset.private_filename)), 'dir for private file should not exist'
    assert !File.exist?(@asset.public_filename), 'public file should not exist'
  end

  def test_access
    @asset = FactoryGirl.create :png_asset
    assert @asset.public?
    @asset.update_access

    assert File.exist?(@asset.public_filename), 'public file "%s" should exist' % @asset.public_filename
    assert File.symlink?(File.dirname(@asset.public_filename)), 'dir of public file should be a symlink'
    @asset.instance_eval do
      def public?
        false
      end
    end
    @asset.update_access
    assert !File.exist?(@asset.public_filename), 'public file should NOT exist'
    assert !File.symlink?(File.dirname(@asset.public_filename)), 'dir of public file should NOT be a symlink'
  end

  def test_thumbnail_generation_handled_by_thumbnails
    @asset = FactoryGirl.create :image_asset
    @asset.thumbnails.each{|thumb| thumb.expects(:generate)}
    @asset.generate_thumbnails
  end

  def test_thumbnail_integration
    start_thumb_count = Thumbnail.count
    @asset = FactoryGirl.create :image_asset
    @asset.generate_thumbnails

    thumb_file = @asset.thumbnail_filename(:small)
    @thumb1 = @asset.private_filename thumb_file
    @thumb_v1 = @asset.versions.latest.private_filename thumb_file
    assert File.exist?(@thumb1), '%s should exist' % @thumb1
    assert File.exist?(@thumb_v1), '%s should exist' % @thumb_v1

    @asset.uploaded_data = upload_data('image.png')
    @asset.save
    @asset = Asset.find(@asset.id)

    assert_equal 3, @asset.thumbnails.length, 'there should be three thumbnails'
    assert_equal 2, @asset.versions.length, 'there should be two versions'
    @asset.versions.each do |version|
      assert_equal 3, version.thumbnails.length, 'each version should have thumbnails'
    end

    @asset.generate_thumbnails
    thumb_file = @asset.thumbnail_filename(:small)
    @thumb2 = @asset.private_filename thumb_file
    @thumb_v2 = @asset.versions.latest.private_filename thumb_file

    assert File.exist?(@thumb2), '%s should exist (new thumb)' % @thumb2
    assert File.exist?(@thumb_v2), '%s should exist (new versioned thumb)' % @thumb_v2
    assert !File.exist?(@thumb1), '%s should NOT exist (old filename)' % @thumb1

    end_thumb_count = Thumbnail.count
    assert_equal start_thumb_count+9, end_thumb_count, 'there should be exactly 9 more thumbnail objects'
  end

  def test_type_changes
    @asset = FactoryGirl.create :image_asset
    @word_asset = FactoryGirl.create :word_asset
    assert_equal 'Image', @asset.type
    assert_equal 3, @asset.thumbnails.count

    # change to Text
    @asset.uploaded_data = upload_data('msword.doc')
    @asset.save
    assert_equal 'application/msword', @asset.content_type
    assert_equal 'Text', @asset.type
    # relative comparison to account for CI which does not have
    # a transmogrifier for word right now.
    assert_equal @word_asset.thumbnails.count, @asset.thumbnails.count

    # change back
    @asset = Asset.find(@asset.id)
    @asset.uploaded_data = upload_data('gears.jpg')
    @asset.save
    assert_equal 'Image', @asset.type
    assert_equal 3, @asset.thumbnails.count
  end

  def test_simple_upload
   @asset = FactoryGirl.create :png_asset
   assert File.exist?( @asset.private_filename ), 'the private file should exist'
   assert read_file('image.png') == File.read(@asset.private_filename), 'full_filename should be the uploaded_data'
  end

  def test_thumbnail_size_after_new_upload
    @asset = FactoryGirl.create :small_image_asset
    assert_equal 64, @asset.width, 'width must match file'
    assert_equal 64, @asset.height, 'height must match file'
    @asset.uploaded_data = upload_data('bee.jpg')
    @asset.save
    assert_equal 333, @asset.width, 'width must match after new upload'
    assert_equal 500, @asset.height, 'height must match after new upload'
  end

  def test_thumbnail_size_guess
    @asset = FactoryGirl.create :image_asset
    assert_equal 333, @asset.width, 'width must match after new upload'
    assert_equal 500, @asset.height, 'height must match after new upload'
    assert_equal 43, @asset.thumbnail(:small).width, 'guess width should match actual'
    assert_equal 64, @asset.thumbnail(:small).height, 'guess height should match actual'
  end


  def test_dimension_integration
    skip_if_graphics_magick_missing
    @asset = FactoryGirl.create :image_asset
    @asset.generate_thumbnails
    assert_equal 43, @asset.thumbnail(:small).width, 'actual width should be 43'
    assert_equal 64, @asset.thumbnail(:small).height, 'actual height should be 64'

    assert_equal 43, @asset.versions.latest.thumbnail(:small).width, 'actual width of versioned thumb should be 43'
    assert_equal 64, @asset.versions.latest.thumbnail(:small).height, 'actual height of versioned thumb should be 64'

    assert_equal ["43","64"], Media.dimensions(@asset.thumbnail(:small).private_filename)
    assert_equal ["133","200"], Media.dimensions(@asset.thumbnail(:medium).private_filename)
  end

  def test_odt_integration
    skip_if_libre_office_missing
    skip_if_graphics_magick_missing

    @asset = Asset.create_from_params uploaded_data: upload_data('test.odt')
    assert_equal 'Asset::Doc', @asset.class.name
    @asset.generate_thumbnails

    # pdf's are the basis for the other thumbnails. So let's check that first.
    assert_thumb_exists @asset, 'pdf'
  end

  def test_doc_integration
    skip_if_libre_office_missing
    skip_if_graphics_magick_missing

    @asset = Asset.create_from_params uploaded_data: upload_data('msword.doc')
    assert_equal 'Asset::Text', @asset.class.name
    @asset.generate_thumbnails

    # pdf's are the basis for the other thumbnails. So let's check that first.
    assert_thumb_exists @asset, 'pdf'

    @asset.thumbnails.each do |thumb|
      assert thumb.ok?, 'generating thumbnail "%s" should have succeeded' % thumb.name
      assert thumb.private_filename, 'thumbnail "%s" should exist' % thumb.name
    end
  end

  def test_binary
    @asset = Asset.create_from_params uploaded_data: upload_data('raw_file.bin')
    assert_equal Asset, @asset.class, 'asset should be an Asset'
    assert_equal 'Asset', @asset.versions.earliest.versioned_type, 'version should by of type Asset'
  end

  def test_failure_on_corrupted_file
    Media::Transmogrifier.suppress_errors = true
    @asset = Asset.create_from_params uploaded_data: upload_data('corrupt.jpg')
    @asset.generate_thumbnails
    @asset.thumbnails.each do |thumb|
      assert thumb.failure?, 'generating the thumbnail should have failed'
    end
    Media::Transmogrifier.suppress_errors = false
  end

  def test_failure
    failing = mock
    failing.stubs(:run).returns false
    transmogrifier_for(input_type: 'image/jpeg').times(5).returns failing
    @asset = Asset.create_from_params uploaded_data: upload_data('photo.jpg')
    @asset.generate_thumbnails
    @asset.thumbnails.each do |thumb|
      assert_equal true, thumb.failure?, 'generating the thumbnail should have failed'
    end
  end

  def test_success
    failing = mock
    failing.stubs(:run).returns true
    transmogrifier_for(input_type: 'image/jpeg').times(5).returns failing
    @asset = Asset.create_from_params uploaded_data: upload_data('photo.jpg')
    @asset.generate_thumbnails
    @asset.thumbnails.each do |thumb|
      assert_equal true, thumb.failure?, 'generating the thumbnail should have failed'
    end
  end

  # we currently do not have a xcf transmogrifier
  def test_no_thumbs_for_xcf
    @asset = Asset.create_from_params uploaded_data: upload_data('image.xcf')
    @asset.generate_thumbnails
    assert_equal Asset::Image, @asset.class
    assert_equal 0, @asset.thumbnails.count
  end

  def test_content_type
    assert_equal 'application/octet-stream', Asset.new.content_type
  end

  def test_user_versions
    asset = Asset.create! uploaded_data: upload_data('empty.jpg')
    asset.update_attributes user: users(:blue),
      uploaded_data: upload_data('photo.jpg')
    assert_nil asset.versions.first.user
    assert_equal users(:blue), asset.versions.last.user
  end

  def test_build_asset
    asset = Asset.build(uploaded_data: upload_data('photo.jpg'))
    asset.valid? # running validations will load metadata
    assert asset.filename.present?
  end

  def test_empty_files_get_filename
    asset = Asset.build(uploaded_data: upload_data('empty.jpg'))
    assert asset.valid?
    assert asset.filename.present?
  end

  def test_search
    user = users(:kangaroo)
    correct_ids = Asset.all.map do |asset|
      asset.page_terms = asset.page.page_terms
      asset.save
      asset.id if user.may?(:view, asset.page)
    end.compact.sort
    ids = Asset.visible_to(user).media_type(:image).pluck(:id)
    assert_equal correct_ids, ids.sort
  end

  protected

  def skip_if_libre_office_missing
    # must have LO installed
    if !Media::LibreOfficeTransmogrifier.new.available?
      skip "LibreOffice converter is not available. Either LibreOffice is not installed or it can not be started. Skipping AssetTest#test_doc."
      return
    end
  end

  def skip_if_graphics_magick_missing
    # must have GM installed
    if !Media::GraphicsMagickTransmogrifier.new.available?
      skip "GraphicMagick converter is not available. Either GraphicMagick is not installed or it can not be started. Skipping AssetTest#test_doc."
      return
    end
  end

  def transmogrifier_for(options = {})
    Media::Transmogrifier.stubs(:new).with(all_of(
      has_key(:input_file),
      has_key(:output_file),
      has_entries(options)
    ))
  end

  def assert_thumb_exists(asset, thumb)
    name = asset.thumbnail_filename(thumb)
    assert asset.thumbnail_exists?(thumb),
      "Could not find #{asset.private_filename(name)}"
  end
end
