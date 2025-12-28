import { Container as UIContainer, Heading, Table, Button } from "@medusajs/ui"
import { useQuery } from "@tanstack/react-query"
import { Link } from "react-router-dom"
import { Plus } from "@medusajs/icons"

const PostList = () => {
    const { data, isLoading } = useQuery({
        queryFn: async () => {
            const res = await fetch("/admin/blog")
            return await res.json()
        },
        queryKey: ["blog-posts"],
    })

    return (
        <UIContainer className="p-8 flex flex-col gap-8">
            <div className="flex items-center justify-between">
                <Heading level="h1">Blog Posts</Heading>
                <Link to="/blog/create">
                    <Button variant="secondary">
                        <Plus />
                        Create Post
                    </Button>
                </Link>
            </div>

            {isLoading && <div>Loading...</div>}

            {data && (
                <Table>
                    <Table.Header>
                        <Table.Row>
                            <Table.HeaderCell>Title</Table.HeaderCell>
                            <Table.HeaderCell>Slug</Table.HeaderCell>
                            <Table.HeaderCell>Category</Table.HeaderCell>
                            <Table.HeaderCell>Actions</Table.HeaderCell>
                        </Table.Row>
                    </Table.Header>
                    <Table.Body>
                        {data.posts.map((post: any) => (
                            <Table.Row key={post.id}>
                                <Table.Cell>{post.title}</Table.Cell>
                                <Table.Cell>{post.slug}</Table.Cell>
                                <Table.Cell>{post.category}</Table.Cell>
                                <Table.Cell>
                                    <Link to={`/blog/${post.id}`} className="text-ui-fg-interactive hover:underline">
                                        Edit
                                    </Link>
                                </Table.Cell>
                            </Table.Row>
                        ))}
                    </Table.Body>
                </Table>
            )}
        </UIContainer>
    )
}

export default PostList
