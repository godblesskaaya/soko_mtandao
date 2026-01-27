class EditableImage {
  final String path; // local or remote
  final bool isRemote;

  EditableImage.remote(this.path) : isRemote = true;
  EditableImage.local(this.path) : isRemote = false;
}
