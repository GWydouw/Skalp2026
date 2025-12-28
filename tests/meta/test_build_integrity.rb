# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "digest"
require "json"
require "tmpdir"

# Load the class under test
require_relative "../../SOURCE/jt_hyperbolic_curves/integrity_check"

class TestBuildIntegrity < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @ext_dir = File.join(@tmp_dir, "jt_hyperbolic_curves")
    FileUtils.mkdir_p(@ext_dir)
  end

  def teardown
    FileUtils.remove_entry @tmp_dir
  end

  def test_integrity_check_pass
    # 1. Create a dummy file
    filename = "test_file.rb"
    file_path = File.join(@ext_dir, filename)
    File.write(file_path, "puts 'hello'")
    
    # 2. Calculate Hash
    hash = Digest::SHA256.file(file_path).hexdigest
    
    # 3. Create Manifest
    # Note: verify_installation expects rel_path from root_dir
    # root_dir is @tmp_dir
    # rel_path is "jt_hyperbolic_curves/test_file.rb"
    rel_path = File.join("jt_hyperbolic_curves", filename)
    
    manifest_data = {
      "files" => {
        rel_path => hash
      }
    }
    
    File.write(File.join(@ext_dir, "manifest.json"), manifest_data.to_json)
    
    # 4. Run Check
    result = JtHyperbolicCurves::IntegrityCheck.verify_installation(@tmp_dir)
    
    assert_equal :ok, result[:status], "Integrity check should pass for valid files"
  end

  def test_integrity_check_fail_modified
    # 1. Create a file
    filename = "test_file.rb"
    file_path = File.join(@ext_dir, filename)
    File.write(file_path, "original content")
    
    # 2. calc hash of ORIGINAL
    hash = Digest::SHA256.file(file_path).hexdigest
    
    # 3. Manifest expects ORIGINAL
    rel_path = File.join("jt_hyperbolic_curves", filename)
    manifest_data = { "files" => { rel_path => hash } }
    File.write(File.join(@ext_dir, "manifest.json"), manifest_data.to_json)
    
    # 4. Modify the file!
    File.write(file_path, "TAMPERED CONTENT")
    
    # 5. Run Check
    result = JtHyperbolicCurves::IntegrityCheck.verify_installation(@tmp_dir)
    
    assert_equal :failed, result[:status]
    assert_includes result[:details][:modified], rel_path
  end

  def test_integrity_check_fail_missing
     # 1. Manifest expects a file
     rel_path = File.join("jt_hyperbolic_curves", "missing.rb")
     manifest_data = { "files" => { rel_path => "somehash" } }
     File.write(File.join(@ext_dir, "manifest.json"), manifest_data.to_json)
     
     # 2. Run Check (File is not created)
     result = JtHyperbolicCurves::IntegrityCheck.verify_installation(@tmp_dir)
     
     assert_equal :failed, result[:status]
     assert_includes result[:details][:missing], rel_path
  end
end
