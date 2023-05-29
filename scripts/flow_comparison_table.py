import sys
from lxml import etree


def compare_xml_files(file1, file2):
    tree1 = etree.parse(file1)
    tree2 = etree.parse(file2)
    root1 = tree1.getroot()
    root2 = tree2.getroot()

    all_changes = []

    for element1, element2 in zip(root1.iter(), root2.iter()):
        changes = compare_elements(element1, element2)
        all_changes.extend(changes)

    return all_changes


def compare_elements(element1, element2):
    changes = []

    if element1.text != element2.text:
        changes.append({
            "old": element1.text,
            "new": element2.text,
            "path": get_element_path(element1),
            "element": get_element_name(element1)
        })

    return changes


def get_element_path(element):
    namespaces = {
        "metadata": "http://soap.sforce.com/2006/04/metadata"
    }

    path = [element.tag.replace(namespaces["metadata"], "")]

    parent = element.getparent()
    while parent is not None:
        tag = parent.tag.replace(namespaces["metadata"], "")
        path.insert(0, tag)
        parent = parent.getparent()

    return " > ".join(path)


def get_element_name(element):
    namespaces = {
        "metadata": "http://soap.sforce.com/2006/04/metadata"
    }

    tag = element.tag.replace(namespaces["metadata"], "")

    if tag == "interviewLabel":
        return "Interview Label"
    elif tag == "label":
        return "Label"
    else:
        return tag


def print_changes_table(changes):
    header = f"{'Old Value':<30} | {'New Value':<30} | {'Path':<60} | {'Element':<20}"
    print(header)
    print("-" * len(header))

    for change in changes:
        old_value = f"{change['old']}"
        new_value = f"{change['new']}"
        path = change['path'].replace("{}", "")
        element = change['element'].replace("{}", "")
        row = f"{old_value:<30} | {new_value:<30} | {path:<60} | {element:<20}"
        print(row)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python flow_comparison_table.py <old_flow_file> <new_flow_file>")
    else:
        changes = compare_xml_files(sys.argv[1], sys.argv[2])
        print_changes_table(changes)
