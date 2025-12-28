
  def ccA(faces)
    face_parents = []
    for face in faces
      next if face.deleted?
      face_parents += face.parent.instances unless face.parent.class == Sketchup::Model
    end
    return face_parents
    #self.instance_eval {undef :ccA}
  end
